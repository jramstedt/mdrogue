import type { DecodedPng } from "fast-png"
import { patternSize, spriteMaxPatternsPerDimension, type Rect } from "./megadrive.ts"

type IndexGrid = (number | undefined)[][]
export type PaletteIndexMap = { width: number; height: number; data: Uint8ClampedArray; }

/**
 * Tries to get best one pattern (8x8) sprites that match the whole frame.
 * Tries 7*7 times with different offsets (-7 -> 0).
 * @returns All sprites and grid with indices to sprites
 */
export function getBestSpritesGrid (fullFrame: Rect, image: PaletteIndexMap) {
  const gridWidthInCells = Math.ceil(fullFrame[2] / patternSize) + 1
  const gridHeightInCells = Math.ceil(fullFrame[3] / patternSize) + 1
  const patternMask = patternSize - 1

  let bestResult: Rect[] | undefined = undefined
  let bestGrid: IndexGrid | undefined = undefined

  for (let xOffset = -patternMask; xOffset <= 0; ++xOffset) {
    for (let yOffset = -patternMask; yOffset <= 0; ++yOffset) {
      const sprites: Rect[] = []
      const spriteGrid = Array.from({ length: gridHeightInCells }, () => Array.from({ length: gridWidthInCells }) as (number | undefined)[] )

      for (let cellX = 0; cellX < gridWidthInCells + 1; ++cellX) {
        for (let cellY = 0; cellY < gridHeightInCells + 1; ++cellY) {
          const sprite: Rect = [fullFrame[0] + xOffset + cellX * patternSize, fullFrame[1] + yOffset + cellY * patternSize, patternSize, patternSize]

          if (isSpriteEmpty(fullFrame, sprite, image)) continue
          // @ts-expect-error Should be defined.
          spriteGrid[cellY][cellX] = sprites.length
          sprites.push(sprite)
        }
      }

      if (bestResult === undefined || bestResult.length > sprites.length) {
        bestResult = sprites
        bestGrid = spriteGrid
      }
    }
  }

  return [bestResult, bestGrid] as const
}

/**
 * Checks if sprite has any non transparent colors (not palette index 0)
 */
export function isSpriteEmpty (fullFrame: Rect, sprite: Rect, image: PaletteIndexMap) {
  const { data: spritesheetPixels, width, height } = image

  const minX = Math.max(fullFrame[0], 0)
  const minY = Math.max(fullFrame[1], 0)
  const maxX = Math.min(fullFrame[0] + fullFrame[2], width) - 1
  const maxY = Math.min(fullFrame[1] + fullFrame[3], height) - 1
  const stripe = width

  for (let y = 0; y < sprite[3]; ++y) {
    const row = sprite[1] + y
    if (row < minY || row > maxY) continue
    const rowOffset = row * stripe

    for (let x = 0; x < sprite[2]; ++x) {
      const column = sprite[0] + x
      if (column < minX || column > maxX) continue
      if (spritesheetPixels[rowOffset + column] !== 0) return false
    }
  }

  return true
}

export function mergeSprites (sprites: Rect[], grid: IndexGrid) {
  for (let cellY = 0; cellY < grid.length; ++cellY) {
    const cellRow = grid[cellY]
    if (cellRow === undefined) break

    for (let cellX = 0; cellX < cellRow.length; ++cellX) {
      let w = 0
      while (w < spriteMaxPatternsPerDimension && isValidCell(sprites, grid, cellX + w, cellY))
        ++w
      
      if (w === 0) continue // No valid tile in this cell.

      let h = 1
      height: while (h < spriteMaxPatternsPerDimension) {
        for (let x = 0; x < w; ++x)
          if (!isValidCell(sprites, grid, cellX + x, cellY + h)) break height

        if (w < spriteMaxPatternsPerDimension && (isValidCell(sprites, grid, cellX - 1, cellY + h) || isValidCell(sprites, grid, cellX + w, cellY + h))) // Could next row extend more to left or right if it was it's own sprite?
          break

        ++h
      }
      
      // Create new sprite and update grid. Old sprites are left.
      const originSprite = sprites[cellRow[cellX]!]!
      if (w > 1 || h > 1) {
        const spriteIndex = sprites.length
        sprites.push([originSprite[0], originSprite[1], w * patternSize, h * patternSize])
        
        // console.log(`X${cellX} Y${cellY} W${w} H${h}`)

        for (let y = 0; y < h; ++y) {
          const row = grid[cellY + y]
          if (row === undefined) break
          for (let x = 0; x < w; ++x) {
            row[cellX + x] = spriteIndex
          }
        }
      }
    }
  }
}

function isSinglePattern (sprite: Rect | undefined) {
  return sprite !== undefined && sprite[2] === patternSize && sprite[3] === patternSize
}

function isValidCell (sprites: readonly Rect[], grid: IndexGrid, x: number, y: number) {
  if (x < 0 || y < 0) return false
  if (y >= grid.length || x >= (grid[y]?.length ?? 0)) return false

  const cell = grid[y]?.[x]
  return cell !== undefined && isSinglePattern(sprites[cell])
}
