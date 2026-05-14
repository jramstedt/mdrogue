import { readFile, writeFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { Image, Canvas, createImageData, CanvasRenderingContext2D } from 'canvas'
import RgbQuant, { type Triplet } from 'rgbquant'
import { utils } from 'image-q'
import type { Frame } from '@kayahr/aseprite'

import { getBestSpritesGrid, isSpriteEmpty, mergeSprites, type PaletteIndexMap } from './optimize.ts'
import { concatenate, type SubRect } from './utils.ts'

export const megaDriveLadder = [0x00, 0x34, 0x57, 0x74, 0x90, 0xAC, 0xCE, 0xFF]

export const imageQPalette = new utils.Palette()
imageQPalette.add(utils.Point.createByRGBA(0, 0, 0, 0)) // First index is always transparent
export const rgbQuantPalette: Triplet[] = []
for (let r = 0; r <= 0b111; ++r)
  for (let g = 0; g <= 0b111; ++g)
    for (let b = 0; b <= 0b111; ++b) {
      rgbQuantPalette.push([megaDriveLadder[r] ?? 0, megaDriveLadder[g] ?? 0, megaDriveLadder[b] ?? 0])
      imageQPalette.add(utils.Point.createByRGBA(megaDriveLadder[r] ?? 0, megaDriveLadder[g] ?? 0, megaDriveLadder[b] ?? 0, 255))
    }

export type Pattern = { normal: Uint32Array, flipped: Uint32Array }
export type Rect = [x: number, y: number, width: number, height: number]
export type Section = SubRect & { highPriority: boolean, palette: 0 | 1 | 2 | 3,  name: string }

export const patternSize = 8 // Mega Drive uses 8x8 pixel patterns.
export const patternBytes = 4 * 8
export const spriteMaxPatternsPerDimension = 4

export function generateMegaDriveTilemap (inputSections: Section[], patterns: Pattern[]) {
  const patternStartOffset = patterns.length

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

  const patternNameBuffer = new ArrayBuffer(64 * 1024) // Mega Drive 64k VRAM
  const sectionOffset: { name: string, offset: number }[] = []

  let dataOffset = 0
  for (const { width, height, offset, data, widthStride, highPriority, palette, name } of inputSections) {
    const widthPatterns = width >>> 3
    const heighPatterns = height >>> 3

    sectionOffset.push({ name, offset: dataOffset })

    const patternNameView = new DataView(patternNameBuffer, dataOffset, widthPatterns * heighPatterns * 2) // 2 bytes per name
    dataOffset += patternNameView.byteLength

    for (let y = 0; y < height; y += patternSize) {
      for (let x = 0; x < width; x += patternSize) {
        const pattern: Pattern = { normal: new Uint32Array(8), flipped: new Uint32Array(8) }  // 8 * 32bits = 32 bytes per pattern

        for (let r = 0; r < patternSize; ++r) {
          let normal = 0
          let flipped = 0

          const rowOffset = offset + ((y + r) * widthStride) + x

          for (let p = 0; p < patternSize; ++p) {
            const colorIndex = (data[rowOffset + p] ?? 0) & 0x0F

            normal = (normal << 4) | colorIndex
            flipped = (flipped >>> 4) | (colorIndex << 28)
          }

          pattern.normal[r] = normal
          pattern.flipped[r] = flipped
        }

        let tilePattern = findPattern(pattern)
        if (highPriority) tilePattern |= 0x8000
        tilePattern |= (palette & 0b11) << 13

        patternNameView.setUint16(((y >>> 3) * widthPatterns + (x >>> 3)) * 2, tilePattern)
      }
    }

    console.log(`section ${name} tilemap: ${widthPatterns}x${heighPatterns} bytes: ${patternNameView.byteLength}`)
  }

  const newPatterns = patterns.length - patternStartOffset
  console.log(`new patterns: ${newPatterns} bytes: ${newPatterns << 3} (all patterns: ${patterns.length} bytes: ${patterns.length << 3})`)

  return { tileMap: patternNameBuffer.slice(0, dataOffset), sectionOffset }
}

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
      palette: rgbQuantPalette,
    })
    toMegaDrive.sample(pixelArray)

    const megaDrive = toMegaDrive.reduce(pixelArray)
    quant.sample(megaDrive)

    return { canvas, pixelArray, highPriority: layer.highPriority }
  }))

  const mapWidth = Math.max(...inputDatas.map(data => data.canvas.width))
  const mapHeight = Math.max(...inputDatas.map(data => data.canvas.height))
  const mapWidthChunks = mapWidth >>> (5 + 3)
  const mapHeightChunks = mapHeight >>> (5 + 3)

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
  await writeFile(resolve(targetDirectory, `${prefix}.pal`), writePalette(new Uint32Array(quant.idxi32)))
  //#endregion

  return patterns
}

// TODO tile vs sprite priority for slice
export async function writeMegaDriveSprites (slice: boolean, image: PaletteIndexMap, animation: { name: string, frames: readonly Frame[] }, targetDirectory: string, state: { patterns: ArrayBuffer, patternsWritten: number, dplcPatternsNeeded: number }, ctx?:CanvasRenderingContext2D) {
  const frames: Rect[][] = []
  
  let frameOffset = 0
  const frameOffsets: number[] = []

  let patternOffset = 0
  const dplc: number[] = []

  const animationBuffer = new ArrayBuffer(4 * 1024 * 1024) // Max Mega Drive ROM size
  let dataOffset = 0
  
  //#region Header with offsets
  // TODO We could have just one HEADER dataview and constant offsets to it
  const animationOffset = new DataView(animationBuffer, dataOffset, 2)
  dataOffset += animationOffset.byteLength

  const frameOffsetsOffset = new DataView(animationBuffer, dataOffset, 2)
  dataOffset += frameOffsetsOffset.byteLength

  const dplcOffset = new DataView(animationBuffer, dataOffset, 2)
  dataOffset += dplcOffset.byteLength
  //#endregion

  //#region Animation data
  animationOffset.setUint16(0, dataOffset)  // Animation data starts here.
  const frameCount = new DataView(animationBuffer, dataOffset, 2)
  dataOffset += frameCount.byteLength

  for (const { frame } of animation.frames) {
    // TODO handle empty frames in middle of animation. Handle forced empty frames to animation data.
    const fullFrame: Rect = [frame.x, frame.y, frame.w, frame.h]

    if (isSpriteEmpty(fullFrame, fullFrame, image)) continue

    frameOffsets.push(frameOffset)
    
    let patternsWritten = 0

    if (slice) {
      const [sprites, grid] = getBestSpritesGrid(fullFrame, image)
      if (sprites === undefined || grid === undefined) continue

      mergeSprites(sprites, grid)
      // TODO Shrink sprites. Shrink (remove empty pixel rows&columns) sprites on each side.

      const usedSpriteIndices = Array.from(new Set(grid.flat()))
      const usedSprites = usedSpriteIndices.map(cell => cell !== undefined ? sprites[cell] : undefined).filter(sprite => sprite != undefined)
      frames.push(usedSprites)

      for (let spriteIndex = 0; spriteIndex < usedSprites.length; ++spriteIndex) {
        const sprite = usedSprites[spriteIndex]
        if (sprite === undefined)
          throw new Error(`Missing sprite data for index ${spriteIndex}.`)

        const priority = 0;
        const palette = 0; // TODO parameter
        const verticalFlip = 0;
        const horizontalFlip = 0;

        const spriteData = new DataView(animationBuffer, dataOffset, 8)
        dataOffset += spriteData.byteLength

        spriteData.setUint16(0, sprite[0] & 0x3FF)
        spriteData.setUint16(2, ((sprite[2] & 0b11) << 10) | ((sprite[3] & 0b11) << 8))
        spriteData.setUint16(4, (priority & 0b1) << 15 | (palette & 0b11) << 13 | (verticalFlip & 0b1) << 12 | (horizontalFlip & 0b1) << 11 | patternsWritten & 0x7FF )
        spriteData.setUint16(6, sprite[1] & 0x1FF)

        patternsWritten += writePatterns(fullFrame, sprite, image, state)
        ctx?.strokeRect(sprite[0], sprite[1], sprite[2] - 1, sprite[3] - 1)
      }

      frameOffset += usedSprites.length
    } else {
      const sprite = fullFrame
      frames.push([sprite])

      const priority = 0;
      const palette = 0; // TODO parameter
      const verticalFlip = 0;
      const horizontalFlip = 0;

      const spriteData = new DataView(animationBuffer, dataOffset, 8)
      dataOffset += spriteData.byteLength

      spriteData.setUint16(0, sprite[0] & 0x3FF)
      spriteData.setUint16(2, ((sprite[2] & 0b11) << 10) | ((sprite[3] & 0b11) << 8))
      spriteData.setUint16(4, (priority & 0b1) << 15 | (palette & 0b11) << 13 | (verticalFlip & 0b1) << 12 | (horizontalFlip & 0b1) << 11 | patternsWritten & 0x7FF )
      spriteData.setUint16(6, sprite[1] & 0x1FF)

      patternsWritten += writePatterns(fullFrame, sprite, image, state)
      ctx?.strokeRect(sprite[0], sprite[1], sprite[2] - 1, sprite[3] - 1)

      frameOffset++
    }

    state.dplcPatternsNeeded = Math.max(state.dplcPatternsNeeded, patternsWritten)

    dplc.push(patternOffset)
    patternOffset += patternsWritten
  }
  frameOffsets.push(frameOffset)
  dplc.push(patternOffset)

  frameCount.setUint16(0, frames.length)
  //#endregion

  frameOffsetsOffset.setUint16(0, dataOffset)
  const frameOffsetsData = new Uint8Array(animationBuffer, dataOffset, frameOffsets.length)
  dataOffset += frameOffsetsData.byteLength
  frameOffsetsData.set(frameOffsets.map(offset => offset * 8))

  dplcOffset.setUint16(0, dataOffset)
  const dplcData = new Uint8Array(animationBuffer, dataOffset, dplc.length)
  dataOffset += dplcData.byteLength
  dplcData.set(dplc)

  if (frames.length === 0) {
    console.warn(`${animation.name} skipped because of ${frames.length} frames.`)
    return
  }

  // Write animationBuffer
  console.log(`Writing animation ${animation.name} with ${frames.length} frames, sprites/frame ${frames.map(sprites => sprites.length)}, frame offsets ${frameOffsets} and DPLC offsets ${dplc}...`)
  await writeFile(resolve(targetDirectory, `anim${animation.name}.bin`), new DataView(animationBuffer, 0, dataOffset))
}

function writePattern (fullFrame: Rect, patOriginX: number, patOriginY: number, image: PaletteIndexMap, output: { patterns: ArrayBuffer, patternsWritten: number }) {
  const { data: spritesheetPixels } = image

  const pattern = new Uint32Array(output.patterns, output.patternsWritten++ * patternBytes, patternSize)

  const minX = Math.max(fullFrame[0], 0)
  const minY = Math.max(fullFrame[1], 0)
  const maxX = Math.min(fullFrame[0] + fullFrame[2], image.width) - 1
  const maxY = Math.min(fullFrame[1] + fullFrame[3], image.height) - 1
  const stripe = image.width

  for (let y = 0; y < patternSize; ++y) {
    const row = patOriginY + y
    if (row < minY || row > maxY) continue

    const rowOffset = row * stripe
    let rowData = 0

    for (let x = 0; x < patternSize; ++x) {
      const column = patOriginX + x
      rowData <<= 4
      if (column < minX || column > maxX) continue
      rowData |= (spritesheetPixels[rowOffset + column] ?? 0) & 0x0F
    }

    pattern[y] = rowData
  }
}

function writePatterns (fullFrame: Rect, cropFrame: Rect, image: PaletteIndexMap, output: { patterns: ArrayBuffer, patternsWritten: number }) {
  const widthInPatterns = Math.ceil(cropFrame[2] / patternSize)
  const heightInPatterns = Math.ceil(cropFrame[3] / patternSize)

  // MegaDrive: Top to bottom then left to right
  for (let patX = 0; patX < widthInPatterns; ++patX) {
    for (let patY = 0; patY < heightInPatterns; ++patY) {
      writePattern(fullFrame, cropFrame[0] + patX * patternSize, cropFrame[1] + patY * patternSize, image, output)
    }
  }

  return heightInPatterns * widthInPatterns
}

/**
 * ABGR -> 0BGR
 * @param reducedPalette ABGR
 */
export function writePalette (reducedPalette: Uint32Array) {
  const megaDrivePalette = new DataView(new ArrayBuffer(16 * 2))
  for (let index = 0; index < reducedPalette.length; ++index) {
    // ABGR -> 0BGR

    const color = reducedPalette[index] ?? 0
    const b = megaDriveLadder.indexOf((color >>> 16) & 0xFF) << 9
    const g = megaDriveLadder.indexOf((color >>> 8) & 0xFF) << 5
    const r = megaDriveLadder.indexOf(color & 0xFF) << 1
    megaDrivePalette.setUint16(index << 1, b | g | r)
  }

  return megaDrivePalette
}