import console from 'node:console'
import {readFile, writeFile} from 'node:fs/promises'
import {basename, dirname, join, resolve, sep} from 'node:path'
import {distance, image, palette, utils} from 'image-q'
import {encode} from 'fast-png'

import {generateMegaDriveTilemap, imageQPalette, type Section, megaDriveLadder, type Pattern, writePalette} from './megadrive.ts'
import {concatenate, decodePngForImageQ, extractRect, extractRectQ, getIndexArray, type StrideArray, subRect} from './utils.ts'

const [, , jsonFilename, targetDirectory, preview = 'false'] = process.argv

if (jsonFilename === undefined || jsonFilename.length === 0) {
  console.error('Descriptor json filename missing.')
  process.exit(1)
}

if (targetDirectory === undefined || targetDirectory.length === 0) {
  console.error('Target directory missing.')
  process.exit(2)
}

const drawPreview = Boolean(JSON.parse(preview))

type Frame = {
  readonly pngFile?: string,
  readonly name?: string,
  readonly x?: number | "+" | "-"
  readonly y?: number | "+" | "-"
  readonly width?: number
  readonly height?:number
  readonly highPriority?: boolean
  readonly palette?: 0 | 1 | 2 | 3
  readonly preview?: boolean
}

type Descriptor = {
  readonly name: string
  readonly frames: readonly Frame[]
  // readonly palettes: readonly [string, string, string, string] // TODO Load palette from file. Don't create new one.
}

const pngFiles = new Map<string, Promise<utils.PointContainer>>()
const paletteQuantizers = new Map<number, palette.AbstractPaletteQuantizer>()
const reducedPalettes = new Map<number, utils.Palette>()
const reducedIndexedImages = new Map<string, StrideArray>()

const basePath = dirname(jsonFilename)
const descriptors = JSON.parse(await readFile(jsonFilename, { encoding: 'utf8' })) as readonly Descriptor[]

const distanceCalculator = new distance.EuclideanBT709()
// Quantize palettes using nearest color
const nearestColor = new image.NearestColor(distanceCalculator)

for (const { frames, name } of descriptors) {
  let pngFile: string | undefined = undefined
  const origin = { x: 0, y: 0 }
  const size = { width: -1, height: -1 }
  let paletteIndex: 0 | 1 | 2 | 3 = 0
  for (const { x, y, width, height, palette: framePalette, name: frameName, pngFile: framePngFile } of frames) {
    if (framePngFile !== undefined) pngFile = framePngFile
    if (framePalette !== undefined) paletteIndex = framePalette

    if (typeof x === 'number') origin.x = x
    else if (x === '+') origin.x += size.width

    if (typeof y === 'number') origin.y = y
    else if (y === '+') origin.y += size.height

    if (pngFile === undefined) throw new Error(`No pngFile set to ${name} / ${frameName}.`)

    //const pngLoader = pngFiles.getOrInsertComputed(pngFile, pngFile => decodePngForImageQ(pngFile))
    let pngLoader = pngFiles.get(pngFile)
    if (pngLoader === undefined) {
      pngLoader = decodePngForImageQ(resolve(basePath, pngFile))
      pngFiles.set(pngFile, pngLoader)
    }

    const pixelData = await pngLoader

    if (width !== undefined) size.width = width
    else if (size.width < 0) size.width = pixelData.getWidth()

    if (height !== undefined) size.height = height
    else if (size.height < 0) size.height = pixelData.getHeight()

    if (x === '-') origin.x -= size.width
    if (y === '-') origin.y -= size.height

    /*
    paletteQuantizers
      .getOrInsertComputed(paletteIndex, () => new palette.WuQuant(distanceCalculator, 16))
      .sample(nearestColor.quantizeSync(await pngLoader, imageQPalette)) // Sample image as converted to mega drive palette.
    */
    let paletteQuantizer = paletteQuantizers.get(paletteIndex)
    if (paletteQuantizer === undefined) {
      paletteQuantizer = new palette.RGBQuant(distanceCalculator, 16, 1)
      paletteQuantizers.set(paletteIndex, paletteQuantizer)
    }

    const framePoints = extractRectQ(pixelData, [origin.x, origin.y, size.width, size.height])
    //const framePoints = extractRectQ(pixelData, [0, 0, pixelData.getWidth(), pixelData.getHeight()])
    paletteQuantizer.sample(nearestColor.quantizeSync(framePoints, imageQPalette)) // Sample image as converted to mega drive palette.
  }
}

// Create reduced image, tilemap and patterns
//const imageQuantizer = new image.ErrorDiffusionArray(distanceCalculator, image.ErrorDiffusionArrayKernel.FloydSteinberg)
const imageQuantizer = new image.ErrorDiffusionArray(distanceCalculator, image.ErrorDiffusionArrayKernel.Atkinson, false, 2.0 / 16.0)
const allPatterns: Pattern[] = []

for (const { name, frames  } of descriptors) {
  const sections: Section[] = []

  let pngFile: string | undefined = undefined
  const origin = { x: 0, y: 0 }
  const size = { width: -1, height: -1 }
  let paletteIndex: 0 | 1 | 2 | 3 = 0
  let highPriority = false
  for (const { x, y, width, height, highPriority: frameHighPriority, palette: framePalette, name: frameName, pngFile: framePngFile, preview } of frames) {
    if (framePngFile !== undefined) pngFile = framePngFile
    if (framePalette !== undefined) paletteIndex = framePalette
    if (frameHighPriority !== undefined) highPriority = frameHighPriority

    if (typeof x === 'number') origin.x = x
    else if (x === '+') origin.x += size.width

    if (typeof y === 'number') origin.y = y
    else if (y === '+') origin.y += size.height

    if (pngFile === undefined) throw new Error(`No pngFile set to ${name} / ${frameName ?? sections.length}.`)
    const pixelData= await pngFiles.get(pngFile)
    if (pixelData === undefined) throw new Error(`Missing ${pngFile} loader.`)

    if (width !== undefined) size.width = width
    else if (size.width < 0) size.width = pixelData.getWidth()

    if (height !== undefined) size.height = height
    else if (size.height < 0) size.height = pixelData.getHeight()

    if (x === '-') origin.x -= size.width
    if (y === '-') origin.y -= size.height

    /*
    const reducedPalette = reducedPalettes.getOrInsertComputed(paletteIndex, () => {
      const quant = paletteQuantizers.get(paletteIndex)
      if (quant === undefined) throw new Error(`Missing palette ${paletteIndex} quantizer.`)

      const reducedPalette = quant.quantizeSync() // Final palette
      console.log(`Reduced palette ${paletteIndex} to ${reducedPalette.getPointContainer()} colors.`)

      return reducedPalette
    })
    */

    let reducedPalette = reducedPalettes.get(paletteIndex)
    if (reducedPalette === undefined) {
      const quant = paletteQuantizers.get(paletteIndex)
      if (quant === undefined) throw new Error(`Missing palette ${paletteIndex} quantizer.`)

      reducedPalette = quant.quantizeSync() // Final palette

      console.log(`Reduced palette ${paletteIndex} to ${reducedPalette.getPointContainer().getPointArray().length} colors.`)
      reducedPalettes.set(paletteIndex, reducedPalette)
    }

    let reducedIndexedImage = reducedIndexedImages.get(join(pngFile, paletteIndex.toFixed()))
    if (reducedIndexedImage === undefined) {
      const reducedImage = imageQuantizer.quantizeSync(pixelData.clone(), reducedPalette) // Image converted to reduced final palette
      console.log(`Reduced image ${pngFile} to palette ${paletteIndex}.`)

      reducedIndexedImage = { data: getIndexArray(reducedImage, reducedPalette, distanceCalculator), widthStride: reducedImage.getWidth() }
      reducedIndexedImages.set(join(pngFile, paletteIndex.toFixed()), reducedIndexedImage)
    }

    const section = {
      ...subRect(reducedIndexedImage, [origin.x, origin.y, size.width, size.height]),
      highPriority,
      palette: paletteIndex,
      name: frameName ?? `${name}_res_${origin.x}_${origin.y}`
    } satisfies Section

    sections.push(section)

    /*
    Preview
    */
    if (drawPreview && preview) {
      const sectionPixels = extractRect(reducedIndexedImage, [origin.x, origin.y, size.width, size.height])
      const reducedImagePath = resolve(targetDirectory, `${section.name}-reduced.png`)
      console.log(`Writing ${reducedImagePath}...`)
      await writeFile(reducedImagePath, encode({
        channels: 1,
        depth: 8,
        width: size.width,
        height: size.height,
        palette: reducedPalette.getPointContainer().getPointArray().map(point => point.rgba),
        data: sectionPixels
      }))
    }
  }

  const { tileMap, sectionOffset } = generateMegaDriveTilemap(sections, allPatterns)
  sectionOffset.push({ name: `${name}_res_size`, offset: tileMap.byteLength })

  const tilemapPath = resolve(targetDirectory, `${name}-tilemap.bin`)
  console.log(`Writing ${tilemapPath}...`)
  await writeFile(tilemapPath, new Uint16Array(tileMap))

  /*
  const patternsPath = resolve(targetDirectory, `${name}-patterns.bin`)
  console.log(`Writing ${patternsPath}...`)
  await writeFile(patternsPath, newPatterns, { encoding: 'binary' })
   */

  const resPath = resolve(targetDirectory, `${name}-res.asm`)
  console.log(`Writing ${resPath}...`)
  await writeFile(resPath, sectionOffset.map(({ name, offset }) => `${name}\t\tequ ${offset}`).join('\n'))
}

// Save palette
const paletteBaseFilename = basename(jsonFilename, '.json')
for (const [index, reducedPalette] of reducedPalettes) {
  const palettePath = resolve(targetDirectory, `${paletteBaseFilename}-${index}.pal`)
  console.log(`Writing ${palettePath}...`)
  await writeFile(palettePath, writePalette(reducedPalette.getPointContainer().toUint32Array()))
}

// Save all patterns
const allPatternsToWrite = concatenate(...allPatterns.map(pattern => pattern.normal.map(pattern => ((pattern & 0xFF000000) >>> 24) | ((pattern & 0xFF0000) >>> 8) | ((pattern & 0xFF00) << 8) | ((pattern & 0xFF) << 24) )))

const patternsPath = resolve(targetDirectory, `${paletteBaseFilename}-patterns.bin`)
console.log(`Writing ${patternsPath}...`)
await writeFile(patternsPath, allPatternsToWrite, { encoding: 'binary' })

if (drawPreview) {
  /*
  Previews
  */
  for (const [id, strideArray] of reducedIndexedImages) {
    const name = dirname(id)
    const paletteIndex = parseInt(basename(id))

    const reducedPalette = reducedPalettes.get(paletteIndex)
    if (reducedPalette === undefined) continue

    const reducedImagePath = resolve(targetDirectory, `${name.replace(sep, '_')}-pal${paletteIndex}-reduced.png`)
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
}
