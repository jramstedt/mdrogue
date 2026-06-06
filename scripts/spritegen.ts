import { platform } from 'node:os'
import { readFile, writeFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { decode, encode } from 'fast-png'
import { Canvas } from 'canvas'
import { execa } from 'execa'
import { distance, image, palette, utils } from 'image-q'
import type { SpriteSheet } from '@kayahr/aseprite'

import {generateMegaDriveSprites, imageQPalette as megaDrivePalette, patternSize, type Section, type SpriteGeneratorState} from './megadrive.ts'
import {concatenate, getIndexArray, type StrideArray, subRect} from './utils.ts'

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


const state: SpriteGeneratorState = { patterns: [], dplcPatternsNeeded: 0 }

function asesprite () {
  if (platform() === 'win32') return `${process.env['ProgramFiles(x86)']}\\Steam\\steamapps\\common\\Aseprite\\Aseprite.exe`
  else return 'libresprite'
}

const asespriteroptions = ['-b', '-v']

const distanceCalculator = new distance.ManhattanNommyde()
const quant = new palette.WuQuant(distanceCalculator, 16)

console.log("Getting list of layers...")
for await (const layerName of execa`${asesprite()} ${asespriteroptions} --list-layers ${spritesheetPath}`) {
  const sheet = resolve(targetDirectory, `${layerName}.png`)
  const data = resolve(targetDirectory, `${layerName}.json`)
  console.log(`Writing ${spriteMode} of ${layerName} to ${sheet} and ${data}...`)

  if (spriteMode === undefined)
    await execa({stdout: 'inherit', stderr: 'inherit'})`${asesprite()} ${asespriteroptions} --layer=${layerName} ${spritesheetPath} --list-tags --split-tags --ignore-empty --merge-duplicates --filename-format={tag}/{tagframe0000} --sheet-type=rows --sheet=${sheet} --data=${data}`
  else if (spriteMode === 'grid')
    await execa({stdout: process.stdout, stderr: 'inherit'})`${asesprite()} ${asespriteroptions} --format=json-array --layer=${layerName} --split-grid ${spritesheetPath} --sheet-columns=5 --ignore-empty --merge-duplicates --filename-format={frame0000} --sheet-type=rows --sheet=${sheet} --data=${data}`

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

  let strideArray: StrideArray

  // TODO should sample all layers first. Then nearestColor.quantizeSync with reducedPalette, see tilemap.ts

  //#region Quantize
  {
    const nearestColor = new image.NearestColor(distanceCalculator)
    quant.sample(nearestColor.quantizeSync(imagePointContainer, megaDrivePalette)) // Sample image as converted to mega drive palette.

    const reducedPalette = quant.quantizeSync() // Final palette
    const reducedImage = nearestColor.quantizeSync(imagePointContainer, reducedPalette) // Image converted to reduced final palette

    // palettedPixels = { width: imageWidth, height: imageHeight, data: getIndexArray(reducedImage, reducedPalette, distanceCalculator)}

    strideArray = { data: getIndexArray(reducedImage, reducedPalette, distanceCalculator), widthStride: reducedImage.getWidth() }

    const reducedImagePath = resolve(targetDirectory, `${layerName}-reduced.png`)
    console.log(`Reduced palette to ${reducedPalette.getPointContainer().toUint32Array().length} colors.`)
    console.log(`Writing ${reducedImagePath}...`)
    await writeFile(reducedImagePath, encode({
      channels: 1,
      depth: 8, 
      width: strideArray.widthStride,
      height: strideArray.data.length / strideArray.widthStride,
      palette: reducedPalette.getPointContainer().getPointArray().map(point => point.rgba),
      data: strideArray.data
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

      generateMegaDriveSprites(false, [{ ...subRect(strideArray, [frame.frame.x, frame.frame.y, frame.frame.w, frame.frame.h]), highPriority: false, palette: 2, name: `${layerName}.${frameIndex}` }], state )
    }
  } else {
    const sheetFrames = Map.groupBy(Object.entries(sheetData.frames), ([name]) => name.split('/')[0])

    for (const [name, animationFrames] of sheetFrames) {
      if (name === undefined) continue

      const frames = animationFrames.sort((a, b) => parseInt(a[0]?.split('/')[1] ?? '0') - parseInt(b[0]?.split('/')[1] ?? '0')).map(([, frame]) => frame)

      const sections = frames.map(
        (frame, index) => ({ ...subRect(strideArray, [frame.frame.x, frame.frame.y, frame.frame.w, frame.frame.h]), highPriority: false, palette: 2, name: `${layerName}.${name}.${index}` } satisfies Section)
      )

      //await writeMegaDriveSprites(true, palettedPixels, { name: `${layerName}.${name}`, frames }, targetDirectory, state, ctx)
      generateMegaDriveSprites(true, sections, state )
    }
  }

  console.log(`Writing preview...`)
  await writeFile(resolve(targetDirectory, `${layerName} preview.png`), canvas.toBuffer('image/png'))
}

// Write amount of dplc space needed in VRAM (maximum from all animations)
console.log(`Writing ${state.dplcPatternsNeeded} patterns needed for DPLC in VRAM...`)
await writeFile(resolve(targetDirectory, `dplc.bin`), new Uint8Array([state.dplcPatternsNeeded]))

const allPatternsToWrite = concatenate(...state.patterns.map(pattern => pattern.normal.map(pattern => ((pattern & 0xFF000000) >>> 24) | ((pattern & 0xFF0000) >>> 8) | ((pattern & 0xFF00) << 8) | ((pattern & 0xFF) << 24) )))

console.log(`Writing ${state.patterns.length} patterns...`)
await writeFile(resolve(targetDirectory, `patterns.bin`), allPatternsToWrite)
