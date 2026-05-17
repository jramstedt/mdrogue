import { patternSize, spriteMaxPatternsPerDimension, type Rect } from "./megadrive.ts"
import {isRectEmpty, type SubRect} from './utils.ts'

type IndexGrid = (number | undefined)[][]

/**
 * Tries to get best one pattern (8x8) sprites that match the whole frame.
 * Tries 7*7 times with different offsets (-7 -> 0).
 * @returns All sprites and grid with indices to sprites
 */
export function getBestSpritesGrid (src: SubRect) {
  const gridWidthInCells = Math.ceil(src.width / patternSize) + 1
  const gridHeightInCells = Math.ceil(src.height / patternSize) + 1
  const patternMask = patternSize - 1

  let bestResult: Rect[] | undefined = undefined
  let bestGrid: IndexGrid | undefined = undefined

  for (let xOffset = -patternMask; xOffset <= 0; ++xOffset) {
    for (let yOffset = -patternMask; yOffset <= 0; ++yOffset) {
      const sprites: Rect[] = []
      const spriteGrid = Array.from({ length: gridHeightInCells }, () => Array.from({ length: gridWidthInCells }) as (number | undefined)[] )

      for (let cellX = 0; cellX < gridWidthInCells; ++cellX) {
        for (let cellY = 0; cellY < gridHeightInCells; ++cellY) {
          const sprite: Rect = [xOffset + cellX * patternSize, yOffset + cellY * patternSize, patternSize, patternSize]

          if (isRectEmpty(src, sprite)) continue

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
