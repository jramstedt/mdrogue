import { readFile, writeFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { decode, encode } from 'fast-png'
import { Canvas } from 'canvas'
import { execa } from 'execa'
import { distance, image, palette, utils } from 'image-q'
import type { SpriteSheet } from '@kayahr/aseprite'

import { palette as megaDrivePalette, patternBytes, patternSize, writeMegaDriveSprites } from './megadrive.ts'
import { getIndexArray } from './utils.ts'
import type { PaletteIndexMap } from './optimize.ts'

const [,, spritesheetFilename, targetDirectory, spriteMode = 'tags'] = process.argv

if (spritesheetFilename === undefined || spritesheetFilename.length === 0) {
  console.error('Spritesheet filename missing.')
  process.exit(1)
}

if (targetDirectory === undefined || targetDirectory.length === 0) {
  console.error('Target directory missing.')
  process.exit(2)
}

const spritesheetPath = resolve(spritesheetFilename)
const targetDirectoryPath = resolve(targetDirectory)

console.log(`Processing ${spritesheetPath} to ${targetDirectoryPath}`)

// console.log(spritesheetImage.palette)
// console.log(spritesheetImage.data)

// TODO some results from getBestSpritesGrid doesn't produce best merged result. Test all grids with merging for best result.


const state = { patterns: new ArrayBuffer(64 * 1024) /* Max VDP RAM */, patternsWritten: 0, dplcPatternsNeeded: 0 }

const asesprite = `${process.env['ProgramFiles(x86)']}\\Steam\\steamapps\\common\\Aseprite\\Aseprite.exe`
const asespriteroptions = ['-b', '-v']

var distanceCalculator = new distance.ManhattanNommyde()
const quant = new palette.WuQuant(distanceCalculator, 16)

const newPalette = new utils.Palette()
newPalette.add(utils.Point.createByRGBA(0, 0, 0, 0)) // First index is always transparent
for (const color of megaDrivePalette)
  newPalette.add(utils.Point.createByRGBA(...color, 255))

console.log("Getting list of layers...")
for await (const layerName of execa`${asesprite} ${asespriteroptions} --list-layers ${spritesheetPath}`) {
  const sheet = resolve(targetDirectory, `${layerName}.png`)
  const data = resolve(targetDirectory, `${layerName}.json`)
  console.log(`Writing ${spriteMode} of ${layerName} to ${sheet} and ${data}...`)

  if (spriteMode === undefined)
    await execa({stdout: 'inherit', stderr: 'inherit'})`${asesprite} ${asespriteroptions} --layer=${layerName} ${spritesheetPath} --list-tags --split-tags --ignore-empty --merge-duplicates --filename-format={tag}/{tagframe0000} --sheet-type=rows --sheet=${sheet} --data=${data}`
  else if (spriteMode === 'grid')
    await execa({stdout: process.stdout, stderr: 'inherit'})`${asesprite} ${asespriteroptions} --format=json-array --layer=${layerName} --split-grid ${spritesheetPath} --sheet-columns=5 --ignore-empty --merge-duplicates --filename-format={frame0000} --sheet-type=rows --sheet=${sheet} --data=${data}`

  const spritesheetImage = decode(await readFile(sheet), { checkCrc: true })
  const { width: imageWidth, height: imageHeight, channels: imageChannels, depth: imageDepth, data: imagePixels, palette: imagePalette } = spritesheetImage

  if (imageDepth !== 8 || imagePixels instanceof Uint16Array) {
    console.error(`Unsupported color depth ${imageDepth} (${typeof imagePixels}).`)
    process.exit(1)
  }

  if (imageChannels !== 4 && imageChannels !== 1) {
    console.error(`Unsupported channels ${imageChannels}.`)
    process.exit(1)
  }

  console.log(`channels: ${imageChannels} depth: ${spritesheetImage.depth}bpp data: ${imagePixels.byteLength}bytes`)

  let imagePointContainer: utils.PointContainer
  if (imageChannels === 4) {
    imagePointContainer = utils.PointContainer.fromUint8Array(
      imagePixels,
      imageWidth,
      imageHeight,
    );
  } else {
    if (imagePalette === undefined) {
      console.error(`Only ${imageChannels} channel and no palette.`)
      process.exit(1)
    }

    imagePointContainer = new utils.PointContainer()
    imagePointContainer.setWidth(imageWidth)
    imagePointContainer.setHeight(imageHeight)
    const pointArray = imagePointContainer.getPointArray()
    for (let idx = 0, l = imagePixels.length; idx < l; ++idx) {
      const paletteIndex = imagePixels[idx]
      pointArray[idx] = utils.Point.createByQuadruplet(imagePalette[paletteIndex ?? 0] ?? [0, 0, 0, 0])
    }
  }

  let palettedPixels: PaletteIndexMap

  //#region Quantize
  {
    const nearestColor = new image.NearestColor(distanceCalculator)
    quant.sample(nearestColor.quantizeSync(imagePointContainer, newPalette)) // Sample image as converted to mega drive palette.

    const reducedPalette = quant.quantizeSync() // Final palette
    const reducedImage = nearestColor.quantizeSync(imagePointContainer, reducedPalette) // Image converted to reduced final palette

    palettedPixels = { width: imageWidth, height: imageHeight, data: new Uint8Array(getIndexArray(reducedImage, reducedPalette, distanceCalculator).buffer)}

    const reducedImagePath = resolve(targetDirectory, `${layerName}-reduced.png`)
    console.log(`Reduced palette to ${reducedPalette.getPointContainer().toUint32Array().length} colors.`)
    console.log(`Writing ${reducedImagePath}...`)
    await writeFile(reducedImagePath, encode({
      channels: 1,
      depth: 8, 
      width: palettedPixels.width, 
      height: palettedPixels.height, 
      palette: reducedPalette.getPointContainer().getPointArray().map(point => point.rgba),
      data: palettedPixels.data
    }))
  }
  
  //#endregion
  
  const sheetWidthInCells = Math.ceil(imageWidth / patternSize)
  const sheetHeightInCells = Math.ceil(imageHeight / patternSize)

  console.log(`sheetWidthInCells: ${sheetWidthInCells} sheetHeightInCells: ${sheetHeightInCells}`)

  //#region Preview
  const canvas = new Canvas(sheetWidthInCells * patternSize, sheetHeightInCells * patternSize)
  const ctx = canvas.getContext('2d')
  ctx.imageSmoothingEnabled = false
  ctx.translate(.5, .5)
  ctx.globalAlpha = .25
  ctx.lineJoin = 'round'
  ctx.lineWidth = 1
  ctx.strokeStyle = 'green'
  //#endregion

  const sheetData = JSON.parse(await readFile(data, 'utf-8')) as SpriteSheet

  if (Array.isArray(sheetData.frames)) {
    for (let frameIndex = 0; frameIndex < sheetData.frames.length; ++frameIndex) {
      const frame = sheetData.frames[frameIndex]
      if (frame === undefined) continue

      await writeMegaDriveSprites(false, palettedPixels, { name: `${layerName}.${frameIndex}`, frames: [frame] }, targetDirectory, state, ctx)
    }
  } else {
    const sheetFrames = Map.groupBy(Object.entries(sheetData.frames), ([name]) => name.split('/')[0])

    for (const [name, animationFrames] of sheetFrames) {
      if (name === undefined) continue

      const frames = animationFrames.sort((a, b) => parseInt(a[0]?.split('/')[1] ?? '0') - parseInt(b[0]?.split('/')[1] ?? '0')).map(([, frame]) => frame)

      await writeMegaDriveSprites(true, palettedPixels, { name: `${layerName}.${name}`, frames }, targetDirectory, state, ctx)
    }
  }

  console.log(`Writing preview...`)
  await writeFile(resolve(targetDirectory, `${layerName} preview.png`), canvas.toBuffer('image/png'))
}

// Write amount of dplc space needed in VRAM (maximum from all animations)
console.log(`Writing ${state.dplcPatternsNeeded} patterns needed for DPLC in VRAM...`)
await writeFile(resolve(targetDirectory, `dplc.bin`), new Uint8Array([state.dplcPatternsNeeded]))

console.log(`Writing ${state.patternsWritten} patterns...`)
await writeFile(resolve(targetDirectory, `patterns.bin`), new Uint8Array(state.patterns, 0, state.patternsWritten * patternBytes))
