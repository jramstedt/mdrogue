import { readFile, writeFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { Image, Canvas, createImageData, CanvasRenderingContext2D } from 'canvas'
import RgbQuant, { type Triplet } from 'rgbquant'
import { utils } from 'image-q'

import { getBestSpritesGrid, mergeSprites } from './optimize.ts'
import {concatenate, subRect, type SubRect} from './utils.ts'

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
export type Section = SubRect & { highPriority: boolean, palette: 0 | 1 | 2 | 3, name: string, origin?: { x: number, y: number }, label?: string | undefined }

export const patternSize = 8 // Mega Drive uses 8x8 pixel patterns.
export const patternBytes = 4 * 8 // 8 * 32bits
export const spriteMaxPatternsPerDimension = 4

function buildPattern ({ width, height, data, offset, widthStride }: SubRect, x = 0, y = 0) {
  const pattern: Pattern = { normal: new Uint32Array(patternSize), flipped: new Uint32Array(patternSize) }

  const minX = Math.max(x, 0)
  const minY = Math.max(y, 0)
  const maxX = Math.min(x + patternSize, width) - 1
  const maxY = Math.min(y + patternSize, height) - 1

  for (let dstY = 0, srcY = y; dstY < patternSize; ++dstY, ++srcY) {
    if (srcY < minY || srcY > maxY) continue

    let normal = 0
    let flipped = 0

    const srcOffset = offset + srcY * widthStride

    for (let dstX = 0, srcX = x; dstX < patternSize; ++dstX, ++srcX) {
      normal <<= 4
      flipped >>>= 4

      if (srcX < minX || srcX > maxX) continue

      const colorIndex = (data[srcOffset + srcX] ?? 0) & 0x0F
      normal |= colorIndex
      flipped |= colorIndex << 28
    }

    pattern.normal[dstY] = normal
    pattern.flipped[dstY] = flipped
  }

  return pattern
}

function findPatternIndex (patterns: Pattern[], pattern: Pattern) {
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

export function generateMegaDriveTilemap (inputSections: Section[], patterns: Pattern[], writeSprite: boolean) {
  const patternStartOffset = patterns.length

  const patternNameBuffer = new ArrayBuffer(64 * 1024) // Mega Drive 64k VRAM
  const sectionOffset: { name: string, offset: number, label?: string | undefined }[] = []
  let patternNameDataOffset = 0

  const spriteDataBuffer = new ArrayBuffer(4 * 1024 * 1024) // Max Mega Drive ROM size
  const spriteOffset: { name: string, offset: number, label?: string | undefined }[] = []
  let spriteDataOffset = 0

  for (const section of inputSections) {
    const { highPriority, palette, name, width, height, label } = section

    sectionOffset.push({ name, offset: patternNameDataOffset, label })

    const patternOffset = patterns.length
    const sectionPatterns = writeSprite
      ? buildSpritePatterns(section, patterns)
      : buildTilemapPatterns(section, patterns)

    const patternNameView = new DataView(patternNameBuffer, patternNameDataOffset, sectionPatterns.length * 2) // 2 bytes per name
    patternNameDataOffset += patternNameView.byteLength

    let nameViewOffset = 0
    for (let tilePattern of sectionPatterns) {
      if (highPriority) tilePattern |= 0x8000
      tilePattern |= (palette & 0b11) << 13

      patternNameView.setUint16(nameViewOffset, tilePattern)
      nameViewOffset += Uint16Array.BYTES_PER_ELEMENT
    }

    console.log(`section ${name} (${width}x${height}) tilemap: ${sectionPatterns.length} patterns, ${patternNameView.byteLength} bytes`)

    if (writeSprite) {
      const { width, height } = section
      const priority = highPriority ? 1 : 0

      const widthInPatterns = (width + 7) >>> 3   // Full patterns
      const heightInPatterns = (height + 7) >>> 3

      if (widthInPatterns > 4 || heightInPatterns > 4) {
        console.warn(`Sprite from tilemap ${name} is too large ${widthInPatterns}x${heightInPatterns}`)
        continue
      }

      spriteOffset.push({ name: `spr_${name}`, offset: spriteDataOffset, label })

      const verticalFlip = 0;
      const horizontalFlip = 0;

      const spriteData = new DataView(spriteDataBuffer, spriteDataOffset, 8)
      spriteDataOffset += spriteData.byteLength

      spriteData.setInt16(0, 0)
      spriteData.setUint16(2, ((widthInPatterns & 0b11) << 10) | ((heightInPatterns & 0b11) << 8))
      spriteData.setUint16(4, (priority & 0b1) << 15 | (palette & 0b11) << 13 | (verticalFlip & 0b1) << 12 | (horizontalFlip & 0b1) << 11 | patternOffset & 0x7FF )
      spriteData.setInt16(6, 0)

      console.log(`section ${name} sprite: ${sectionPatterns.length} patterns, ${spriteData.byteLength} bytes`)
    }
  }

  const retSprite = writeSprite ? { spriteData: spriteDataBuffer.slice(0, spriteDataOffset), spriteOffset } : undefined

  const newPatterns = patterns.length - patternStartOffset
  console.log(`new patterns: ${newPatterns} bytes: ${newPatterns << 3} (all patterns: ${patterns.length} bytes: ${patterns.length << 3})`)

  return { tileMap: patternNameBuffer.slice(0, patternNameDataOffset), sectionOffset, ...retSprite }
}

export async function writeMegaDrivePatterns (prefix: string, inputLayers: { filePath: string, highPriority: boolean }[], targetDirectory: string, previousPatterns?: Pattern[]): Promise<Pattern[]> {
  const quant = new RgbQuant({ colors: 16, colorDist: 'manhattan' })

  const inputDatas = await Promise.all(inputLayers.map(async layer => {
    const inputData = await readFile(layer.filePath)

    const image = new Image()
    image.src = inputData

    if (image.width % 256 !== 0) console.warn('Image width not multiple of 256.')
    if (image.height % 256 !== 0) console.warn('Image height not multiple of 256.')

    const canvas = new Canvas(Math.ceil(image.width / patternSize) * patternSize, Math.ceil(image.height / patternSize) * patternSize)
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
    patterns.push({ normal: new Uint32Array(patternSize), flipped: new Uint32Array(patternSize) })
  
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

    for (let y = 0; y < canvas.height; y += patternSize) {
      for (let x = 0; x < canvas.width; x += patternSize) {
        // 32x32 pattern per tile
        // 8x8 pixels per patterns
        const chunkIndex = (y >>> 8) * mapWidthChunks + (x >>> 8)
        const tile = chunks[chunkIndex]

        if (tile === undefined)
          throw new Error(`No chunk found at ${chunkIndex}`)

        let pattern: Pattern = { normal: new Uint32Array(8), flipped: new Uint32Array(8) }  // 8 * 32bits = 32 bytes per pattern
        for (let s = 0; s < patternSize; ++s) {
          let normal = 0
          let flipped = 0

          for (let p = 0; p < patternSize; ++p) {
            const pixelIndex = (y + s) * canvas.width + (x + p)
            const colorIndex = (indexedImage[pixelIndex] ?? 0) & 0x0F

            normal = (normal << 4 | colorIndex) >>> 0
            flipped = (flipped >>> 4 | colorIndex << 28) >>> 0
          }

          pattern.normal[s] = normal
          pattern.flipped[s] = flipped
        }

        // TODO palette index
        let tilePattern = findPatternIndex(patterns, pattern)
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

export type SpriteGeneratorState = { patterns: Pattern[], dplcPatternsNeeded: number }
// TODO tile vs sprite priority for slice
export function generateMegaDriveSprites (slice: boolean, sections: readonly Section[], state: SpriteGeneratorState) {
  const frames: Rect[][] = []
  
  let frameOffset = 0
  const frameOffsets: number[] = []

  let patternOffset = 0
  const dplc: number[] = []

  const animationBuffer = new ArrayBuffer(4 * 1024 * 1024) // Max Mega Drive ROM size
  let dataOffset = 0

  const HEADER_FRAME_OFFSETS = 0
  const HEADER_DPLC_OFFSET = 2
  const HEADER_FRAMES = 4

  const header = new DataView(animationBuffer, dataOffset, 6)
  dataOffset += header.byteLength

  //#region Animation data
  for (const section of sections) {
    const { width, height, palette, highPriority, origin } = section
    const priority = highPriority ? 1 : 0;

    const fullFrame: Rect = [0, 0, width, height]

    // TODO handle empty frames in middle of animation. Handle forced empty frames to animation data.
    //if (isRectEmpty(section, fullFrame)) continue

    frameOffsets.push(frameOffset)

    let patternsWritten = 0
    
    if (slice) {
      const [sprites, grid] = getBestSpritesGrid(subRect(section, fullFrame))
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

        const verticalFlip = 0;
        const horizontalFlip = 0;

        const spriteData = new DataView(animationBuffer, dataOffset, 8)
        dataOffset += spriteData.byteLength

        const spriteX = sprite[0] - (origin?.x ?? 0)
        const spriteY = sprite[1] - (origin?.y ?? 0)
        const spriteWidth = (sprite[2] >>> 3) - 1
        const spriteHeight = (sprite[3] >>> 3) - 1

        // TODO reuse sprite patterns. Find matching pattern sequence instead of always building new patterns

        spriteData.setInt16(0, spriteX)
        spriteData.setUint16(2, ((spriteWidth & 0b11) << 10) | ((spriteHeight & 0b11) << 8))
        spriteData.setUint16(4, (priority & 0b1) << 15 | (palette & 0b11) << 13 | (verticalFlip & 0b1) << 12 | (horizontalFlip & 0b1) << 11 | patternOffset & 0x7FF )
        spriteData.setInt16(6, spriteY)

        patternsWritten += buildSpritePatterns(subRect(section, sprite), state.patterns).length
      }

      frameOffset += usedSprites.length
    } else {
      const sprite = fullFrame
      frames.push([sprite])

      const verticalFlip = 0;
      const horizontalFlip = 0;

      const spriteData = new DataView(animationBuffer, dataOffset, 8)
      dataOffset += spriteData.byteLength

      const spriteX = sprite[0] - (origin?.x ?? 0)
      const spriteY = sprite[1] - (origin?.y ?? 0)
      const spriteWidth = (sprite[2] >>> 3) - 1
      const spriteHeight = (sprite[3] >>> 3) - 1

      spriteData.setInt16(0, spriteX)
      spriteData.setUint16(2, ((spriteWidth & 0b11) << 10) | ((spriteHeight & 0b11) << 8))
      spriteData.setUint16(4, (priority & 0b1) << 15 | (palette & 0b11) << 13 | (verticalFlip & 0b1) << 12 | (horizontalFlip & 0b1) << 11 | patternOffset & 0x7FF )
      spriteData.setInt16(6, spriteY)

      patternsWritten += buildSpritePatterns(subRect(section, sprite), state.patterns).length

      frameOffset++
    }

    state.dplcPatternsNeeded = Math.max(state.dplcPatternsNeeded, patternsWritten)

    dplc.push(patternOffset)
    patternOffset += patternsWritten
  }

  frameOffsets.push(frameOffset)
  dplc.push(patternOffset)
  //#endregion

  /*
  if (frames.length === 0) {
    console.warn(`Skipped because of ${frames.length} frames.`)
    return
  }
  */

  header.setUint16(HEADER_FRAME_OFFSETS, dataOffset)
  const frameOffsetsData = new Uint8Array(animationBuffer, dataOffset, frameOffsets.length)
  dataOffset += frameOffsetsData.byteLength
  frameOffsetsData.set(frameOffsets.map(offset => offset * 8))

  header.setUint16(HEADER_DPLC_OFFSET, dataOffset)
  const dplcData = new Uint8Array(animationBuffer, dataOffset, dplc.length)
  dataOffset += dplcData.byteLength
  dplcData.set(dplc)

  header.setUint16(HEADER_FRAMES, frames.length)

  return { animationBuffer: new DataView(animationBuffer, 0, dataOffset), frames, frameOffsets, dplc }
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

/**
 * Note: returned pattern indices are in row major order. This is to simplify use in tilemaps.
 * Adds sprite patterns to "patterns" in column major order.
 * @returns Pattern indices in row major order.
 */
function buildSpritePatterns (src: SubRect, patterns: Pattern[]) {
  const widthInPatterns = (src.width + 7) >>> 3
  const heightInPatterns = (src.height + 7) >>> 3

  const patternIndices = new Uint16Array(widthInPatterns * heightInPatterns)

  // MegaDrive: Top to bottom then left to right
  for (let patX = 0; patX < widthInPatterns; ++patX) {
    for (let patY = 0; patY < heightInPatterns; ++patY) {
      const nextIndex = patterns.length
      if (nextIndex > 0x07FF)
        throw new Error('Too many patterns.')

      patterns[nextIndex] = buildPattern(src, patX * patternSize, patY * patternSize)
      patternIndices[patY * widthInPatterns + patX] = nextIndex
    }
  }

  return patternIndices
}

/**
 * Adds tilemap patterns to "patterns" in row major order.
 * @returns Pattern indices in row major order.
 */
function buildTilemapPatterns (src: SubRect, patterns: Pattern[]) {
  const widthInPatterns = (src.width + 7) >>> 3
  const heightInPatterns = (src.height + 7) >>> 3

  const patternIndices = new Uint16Array(widthInPatterns * heightInPatterns)

  for (let patY = 0; patY < heightInPatterns; ++patY) {
    for (let patX = 0; patX < widthInPatterns; ++patX) {
      const pattern = buildPattern(src, patX * patternSize, patY * patternSize)
      patternIndices[patY * widthInPatterns + patX] = findPatternIndex(patterns, pattern)
    }
  }

  return patternIndices
}
