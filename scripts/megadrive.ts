import { readFile, writeFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import canvas from 'canvas'
import RgbQuant, { type Triplet } from 'rgbquant'

import { concatenate } from './utils.ts'

const { Image, Canvas, createImageData } = canvas

const megaDriveLadder = [0x00, 0x34, 0x57, 0x74, 0x90, 0xAC, 0xCE, 0xFF]
const palette: Triplet[] = []
for (let r = 0; r <= 0b111; ++r)
  for (let g = 0; g <= 0b111; ++g)
    for (let b = 0; b <= 0b111; ++b)
      palette.push([megaDriveLadder[r] ?? 0, megaDriveLadder[g] ?? 0, megaDriveLadder[b] ?? 0])

export type Pattern = { normal: Uint32Array, flipped: Uint32Array }

export async function writeMegaDrivePatterns (prefix: string, inputLayers: { filePath: string, highPriority: boolean }[], targetDirectory: string, previousPatterns?: Pattern[]): Promise<Pattern[]> {
  const quant = new RgbQuant({ colors: 16, colorDist: 'manhattan' })

  const inputDatas = await Promise.all(inputLayers.map(async layer => {
    const inputData = await readFile(layer.filePath)

    const image = new Image()
    image.src = inputData

    if (image.width % 256 !== 0) console.warn('Image width not multiple of 256.')
    if (image.height % 256 !== 0) console.warn('Image height not multiple of 256.')

    const canvas = new Canvas(Math.ceil(image.width / 8) * 8, Math.ceil(image.height / 8) * 8)
    const ctx = canvas.getContext('2d')
    ctx.drawImage(image, 0, 0, image.width, image.height)

    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
    const pixelArray = new Uint8Array(imageData.data)

    const toMegaDrive = new RgbQuant({
      dithKern: 'Atkinson',
      dithDelta: 1.0 / 8.0,
      colorDist: 'manhattan',
      palette,
    })
    toMegaDrive.sample(pixelArray)

    const megaDrive = toMegaDrive.reduce(pixelArray)
    quant.sample(megaDrive)

    return { canvas, pixelArray, highPriority: layer.highPriority }
  }))

  const mapWidth = Math.max(...inputDatas.map(data => data.canvas.width))
  const mapHeight = Math.max(...inputDatas.map(data => data.canvas.height))
  const mapWidthChunks = mapWidth >>> 8
  const mapHeightChunks = mapHeight >>> 8

  const patterns: Pattern[] = previousPatterns ?? []
  const patternStartOffset = patterns.length
  if (patterns.length === 0)  // No patterns, init with one empty pattern.
    patterns.push({ normal: new Uint32Array(8), flipped: new Uint32Array(8) })
  
  const chunkSizePatterns = 32 * 32
  const patternmap = new ArrayBuffer(mapWidthChunks * mapHeightChunks * chunkSizePatterns * 2)

  const chunks: DataView[] = []
  for (let y = 0; y < mapHeightChunks; y++) {
    const yOffset = y * mapWidthChunks
    for (let x = 0; x < mapWidthChunks; x++) {
      const offset = yOffset + x
      const chunkStartBytes = offset * chunkSizePatterns * 2
      chunks[offset] = new DataView(patternmap, chunkStartBytes, chunkSizePatterns * 2)
    }
  }
  
  // PCCV HAAA AAAA AAAA
  const findPattern = (pattern: Pattern): number => {
    const { normal } = pattern

    for (let patternIndex = 0; patternIndex < patterns.length; ++patternIndex) {
      const target = patterns[patternIndex]

      if (target === undefined) continue

      if (normal[0] === target.normal[0] &&
          normal[1] === target.normal[1] &&
          normal[2] === target.normal[2] &&
          normal[3] === target.normal[3] &&
          normal[4] === target.normal[4] &&
          normal[5] === target.normal[5] &&
          normal[6] === target.normal[6] &&
          normal[7] === target.normal[7])
        return (patternIndex & 0x07FF) | 0x0000

      if (normal[0] === target.flipped[0] &&
          normal[1] === target.flipped[1] &&
          normal[2] === target.flipped[2] &&
          normal[3] === target.flipped[3] &&
          normal[4] === target.flipped[4] &&
          normal[5] === target.flipped[5] &&
          normal[6] === target.flipped[6] &&
          normal[7] === target.flipped[7])
        return (patternIndex & 0x07FF) | 0x0800

      if (normal[0] === target.normal[7] &&
          normal[1] === target.normal[6] &&
          normal[2] === target.normal[5] &&
          normal[3] === target.normal[4] &&
          normal[4] === target.normal[3] &&
          normal[5] === target.normal[2] &&
          normal[6] === target.normal[1] &&
          normal[7] === target.normal[0])
        return (patternIndex & 0x07FF) | 0x1000

      if (normal[0] === target.flipped[7] &&
          normal[1] === target.flipped[6] &&
          normal[2] === target.flipped[5] &&
          normal[3] === target.flipped[4] &&
          normal[4] === target.flipped[3] &&
          normal[5] === target.flipped[2] &&
          normal[6] === target.flipped[1] &&
          normal[7] === target.flipped[0])
        return (patternIndex & 0x07FF) | 0x1800
    }

    const nextIndex = patterns.length
    if (nextIndex > 0x07FF)
      throw new Error('Too many patterns.')

    patterns[nextIndex] = pattern

    return (nextIndex & 0x07FF)
  }

  //const reducedPalette = quant.palette()

  // #region Render preview png
  for (const { canvas, pixelArray, highPriority } of inputDatas) {
    const reducedImage = quant.reduce(pixelArray)
    const output = createImageData(new Uint8ClampedArray(reducedImage), canvas.width, canvas.height)
    const ctx = canvas.getContext('2d')
    ctx.putImageData(output, 0, 0)
    const dataBuffer = canvas.toBuffer('image/png')
    await writeFile(resolve(targetDirectory, `${prefix}-${highPriority ? 'high' : 'low'}-reduced.png`), dataBuffer)
  }
  // #endregion

  console.log(`${prefix}: ${mapWidthChunks}x${mapHeightChunks}`)

  for (const { canvas, pixelArray, highPriority } of inputDatas) {
    const indexedImage = quant.reduce(pixelArray, 2)

    for (let y = 0; y < canvas.height; y += 8) {
      for (let x = 0; x < canvas.width; x += 8) {
        // 32x32 pattern per tile
        // 8x8 pixels per patterns
        const chunkIndex = (y >>> 8) * mapWidthChunks + (x >>> 8)
        const tile = chunks[chunkIndex]

        if (tile === undefined)
          throw new Error(`No chunk found at ${chunkIndex}`)

        let pattern: Pattern = { normal: new Uint32Array(8), flipped: new Uint32Array(8) }  // 8 * 32bits = 32 bytes per pattern
        for (let s = 0; s < 8; ++s) {
          let normal = 0
          let flipped = 0

          for (let p = 0; p < 8; ++p) {
            const pixelIndex = (y + s) * canvas.width + (x + p)
            const colorIndex = (indexedImage[pixelIndex] ?? 0) & 0x0F

            normal = (normal << 4 | colorIndex) >>> 0
            flipped = (flipped >>> 4 | colorIndex << 28) >>> 0
          }

          pattern.normal[s] = normal
          pattern.flipped[s] = flipped
        }

        // TODO palette index
        let tilePattern = findPattern(pattern)
        if (highPriority) tilePattern |= 0x8000

        const patternIndex = (((y >>> 3) & 0x1F) * 32) + ((x >>> 3) & 0x1F)
        tile.setUint16(patternIndex * 2, tilePattern)
      }
    }
  }

  console.log(`${prefix} patterns: ${patterns.length}`)

  await writeFile(resolve(targetDirectory, `${prefix}tilemap.bin`), new Uint8Array(patternmap))

  // 4 bits per pixel, 2 pixels per byte
  // word per row
  // long per pattern

  // patterns 01234567 * 8

  // PCCV HAAA AAAA AAAA

  //#region Patterns
  const allPatterns = concatenate(...patterns.map(pattern => pattern.normal.map(pattern => ((pattern & 0xFF000000) >>> 24) | ((pattern & 0xFF0000) >>> 8) | ((pattern & 0xFF00) << 8) | ((pattern & 0xFF) << 24) )))
  const patternsToWrite = allPatterns.subarray(patternStartOffset * 8)
  await writeFile(resolve(targetDirectory, `${prefix}patterns.bin`), patternsToWrite)
  //#endregion

  //#region Palette
  const reducedPalette = new Uint32Array(quant.idxi32)
  const megaDrivePalette = new Uint16Array(reducedPalette.length)
  for (let index = 0; index < megaDrivePalette.length; ++index) {
    // ABGR -> 0BGR

    const color = reducedPalette[index] ?? 0
    const r = megaDriveLadder.indexOf(color & 0xFF) << 1
    const g = megaDriveLadder.indexOf((color >>> 8) & 0xFF) << 1
    const b = megaDriveLadder.indexOf((color >>> 16) & 0xFF) << 1

    megaDrivePalette[index] = b | (g << 4 | r) << 8
  }
  await writeFile(resolve(targetDirectory, `${prefix}.pal`), megaDrivePalette)
  //#endregion

  return patterns
}
