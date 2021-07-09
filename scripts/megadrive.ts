import { readFile, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { Image, Canvas, createImageData } from 'canvas'
import RgbQuant, { Triplet } from 'rgbquant'
import { concatenate } from './utils'

const megaDriveLadder = [0x00, 0x34, 0x57, 0x74, 0x90, 0xAC, 0xCE, 0xFF]
const palette: Triplet[] = []
for (let r = 0; r <= 0b111; ++r)
  for (let g = 0; g <= 0b111; ++g)
    for (let b = 0; b <= 0b111; ++b)
      palette.push([megaDriveLadder[r], megaDriveLadder[g], megaDriveLadder[b]])

export function writeMegaDrivePatterns (prefix: string, inputFilePath: string, targetDirectory: string): void {
  readFile(inputFilePath, (err, data) => {
    if (err !== null) throw err

    const image = new Image()
    image.src = data

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

    const quant = new RgbQuant({
      colors: 16,
      colorDist: 'manhattan'
    })
    quant.sample(megaDrive)
    
    //const reducedPalette = quant.palette()

    // #region Render preview png
    const reducedImage = quant.reduce(pixelArray)
    const output = createImageData(new Uint8ClampedArray(reducedImage), canvas.width, canvas.height)
    ctx.putImageData(output, 0, 0)
    const dataBuffer = canvas.toBuffer('image/png')
    writeFileSync(resolve(targetDirectory, `${prefix}reduced.png`), dataBuffer)
    // #endregion

    const indexedImage = quant.reduce(pixelArray, 2)

    const mapWidthChunks = canvas.width >>> 8
    const mapHeightChunks = canvas.height >>> 8

    console.log(`${prefix}: ${mapWidthChunks}x${mapHeightChunks}`)
    
    const patterns: { normal: Uint32Array, flipped: Uint32Array }[] = []
    const patternmap = new Uint16Array(mapWidthChunks * mapHeightChunks * 32 * 32)
    const chunks: Uint16Array[] = []

    for (let y = 0; y < mapHeightChunks; y++) {
      const yOffset = y * mapWidthChunks
      for (let x = 0; x < mapWidthChunks; x++) {
        const offset = yOffset + x
        chunks[offset] = new Uint16Array(patternmap, offset * 32 * 32 * Uint16Array.BYTES_PER_ELEMENT, 32 * 32)
      }
    }
    
    // PCCV HAAA AAAA AAAA
    const findPattern = (pattern: { normal: Uint32Array, flipped: Uint32Array }): number => {
      const { normal } = pattern

      let patternIndex = 0
      for (; patternIndex < patterns.length; ++patternIndex) {
        const target = patterns[patternIndex]

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

      return nextIndex
    }

    for (let y = 0; y < canvas.height; y += 8) {
      for (let x = 0; x < canvas.width; x += 8) {
        // 32x32 pattern per tile
        // 8x8 pixels per patterns
        const chunkIndex = (y >>> 8) * mapWidthChunks + (x >>> 8)
        const patternIndex = ((y >>> 3) % 32) * 32 + ((x >>> 3) % 32)

        const tile = chunks[chunkIndex]

        let pattern = { normal: new Uint32Array(8), flipped: new Uint32Array(8) }  // 8 * 32bits = 32 bytes per pattern
        for (let s = 0; s < 8; ++s) {
          let normal = 0
          let flipped = 0

          for (let p = 0; p < 8; ++p) {
            const pixelIndex = (y + s) * canvas.width + (x + p)
            const colorIndex = indexedImage[pixelIndex]

            normal = normal << 4 | (colorIndex & 0x0F)
            flipped = flipped >>> 4 | ((colorIndex & 0x0F) << 28)
          }

          pattern.normal[s] = normal
          pattern.flipped[s] = flipped
        }

        // TODO Priority, palette index

        tile[patternIndex] = findPattern(pattern)
      }
    }

    console.log(`${prefix} patterns: ${patterns.length}`)

    const reducedPalette = new Uint32Array(quant.idxi32)
    const megaDrivePalette = new Uint16Array(reducedPalette.length)
    for (let index = 0; index < megaDrivePalette.length; ++index) {
      // ABGR -> 0BGR

      const color = reducedPalette[index]
      const r = megaDriveLadder.indexOf(color & 0xFF) << 1
      const g = megaDriveLadder.indexOf((color >>> 8) & 0xFF) << 1
      const b = megaDriveLadder.indexOf((color >>> 16) & 0xFF) << 1

      megaDrivePalette[index] = r | g << 4 | b << 8
    }

    const allPatterns = concatenate(...patterns.map(pattern => pattern.normal))

    writeFileSync(resolve(targetDirectory, `${prefix}patterns.bin`), allPatterns)
    writeFileSync(resolve(targetDirectory, `${prefix}tilemap.bin`), patternmap)

    writeFileSync(resolve(targetDirectory, `${prefix}.pal`), megaDrivePalette)

    // 4 bits per pixel, 2 pixels per byte
    // word per row
    // long per pattern

    // patterns 01234567 * 8

    // PCCV HAAA AAAA AAAA
  })
}