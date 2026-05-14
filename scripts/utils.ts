import { readFile } from 'node:fs/promises'
import { utils, distance } from 'image-q'
import { decode } from 'fast-png'
import * as process from 'node:process'
import type { Rect } from './megadrive.ts'

export function concatenate (...arrays: Uint32Array[]): Uint32Array {
  const totalBytes = arrays.reduce((accumulator, currentValue) => accumulator + currentValue.byteLength, 0)
  const buffer = new ArrayBuffer(totalBytes)
  const concatenated = new Uint32Array(buffer)
  arrays.reduce((valuesWritten, array) => (concatenated.set(array, valuesWritten), valuesWritten + array.length), 0)

  return concatenated
}

function getNearestIndex (palette: utils.Palette, colorDistanceCalculator: distance.AbstractDistanceCalculator, point: utils.Point) {
  const pointArray = palette.getPointContainer().getPointArray()

  let minimalDistance = Number.MAX_VALUE
  let idx = 0

  for (let i = 0, l = pointArray.length; i < l; ++i) {
    const p = pointArray[i]
    if (p === undefined) continue

    const distance = colorDistanceCalculator.calculateRaw(point.r, point.g, point.b, point.a, p.r, p.g, p.b, p.a)

    if (distance < minimalDistance) {
      minimalDistance = distance
      idx = i
    }
  }

  return idx
}

export function getIndexArray (pointContainer: utils.PointContainer, palette: utils.Palette, distanceCalculator: distance.AbstractDistanceCalculator) {
  const pointArray = pointContainer.getPointArray()
  const paletteIndices = new Uint8ClampedArray(pointArray.length)

  for (let idx = 0, l = pointArray.length; idx < l; ++idx) {
    const point = pointArray[idx]
    if (point === undefined) continue
    paletteIndices[idx] = getNearestIndex(palette, distanceCalculator, point)
  }

  return paletteIndices
}

export async function decodePngForImageQ (filePath: string) {
  const spritesheetImage = decode(await readFile(filePath), {checkCrc: true})
  const {width: imageWidth, height: imageHeight, channels: imageChannels, depth: imageDepth, data: imageData, palette: imagePalette} = spritesheetImage

  if ((imageDepth !== 1 && imageDepth !== 8) || imageData instanceof Uint16Array) {
    console.error(`Unsupported color depth ${imageDepth} (${typeof imageData}).`)
    process.exit(1)
  }

  if (imageChannels !== 4 && imageChannels !== 1) {
    console.error(`Unsupported channels ${imageChannels}.`)
    process.exit(1)
  }

  console.log(`channels: ${imageChannels} depth: ${imageDepth}bpp data: ${imageData.byteLength}bytes ${imageData.BYTES_PER_ELEMENT}bytes/element`)

  let imagePointContainer: utils.PointContainer
  if (imageChannels === 4) {
    imagePointContainer = utils.PointContainer.fromUint8Array(
      imageData,
      imageWidth,
      imageHeight,
    )
  } else {
    if (imagePalette === undefined) {
      console.error(`Only ${imageChannels} channel and no palette.`)
      process.exit(1)
    }

    imagePointContainer = new utils.PointContainer()
    imagePointContainer.setWidth(imageWidth)
    imagePointContainer.setHeight(imageHeight)
    const pointArray = imagePointContainer.getPointArray()
    if (imageDepth !== 8) {
      const pixelsPerElement = 8 * imageData.BYTES_PER_ELEMENT / imageDepth
      const lastPixel = pixelsPerElement - 1
      const bitmask = (1 << imageDepth) - 1

      for (let idx = 0, l = imageData.length; idx < l; ++idx) {
        const elementData = imageData[idx]
        if (elementData === undefined) {
          console.error('No image data.')
          process.exit(1)
        }

        const elementOffset = idx * pixelsPerElement
        for (let pixel = 0; pixel < pixelsPerElement; ++pixel) {
          const paletteIndex = (elementData >> pixel) & bitmask
          pointArray[elementOffset + (lastPixel - pixel)] = utils.Point.createByQuadruplet(imagePalette[paletteIndex] ?? [0, 0, 0, 0])
        }
      }
    } else {
      for (let idx = 0, l = imageData.length; idx < l; ++idx) {
        const paletteIndex = imageData[idx]
        pointArray[idx] = utils.Point.createByQuadruplet(imagePalette[paletteIndex ?? 0] ?? [0, 0, 0, 0])
      }
    }
  }

  return imagePointContainer
}

export function extractRectQ (src: utils.PointContainer, [x, y, width, height]: Rect) {
  const retPointContainer = new utils.PointContainer()
  retPointContainer.setWidth(width)
  retPointContainer.setHeight(height)

  const srcData = src.getPointArray()
  const srcStripe = src.getWidth()
  const dst = retPointContainer.getPointArray()

  for (let dstY = 0, srcY = y; dstY < height; ++dstY, ++srcY) {
    const dstOffset = dstY*width
    const srcOffset = srcY*srcStripe
    for (let dstX = 0, srcX = x; dstX < width; ++dstX, ++srcX) {
      dst[dstOffset+dstX] = utils.Point.createByUint32(srcData[srcOffset+srcX]!.uint32)
    }
  }

  return retPointContainer
}

export type StrideArray<T = Uint8ClampedArray | Uint8Array | Uint16Array> = { data: T, widthStride: number }
export type SubRect = StrideArray & { width: number, height: number, offset: number }
type StrideSource = StrideArray & Partial<Pick<SubRect, 'offset'>>
export function subRect(src: StrideSource, [x, y, width, height]: Rect): SubRect {
  return {
    data: src.data,
    widthStride: src.widthStride,
    width,
    height,
    offset: (src.offset ?? 0) + y* src.widthStride + x
  }
}

export function getPixel(src: StrideSource, x: number, y: number) {
  return src.data[(src.offset ?? 0) + y * src.widthStride + x]
}

export function setPixel(dst: StrideSource, x: number, y: number, value: number) {
  dst.data[(dst.offset ?? 0) + y * dst.widthStride + x] = value
}

export function copyRect(src: SubRect, dest: StrideSource) {
  for (let y = 0; y < src.height; ++y) {
    const dstOffset = (dest.offset ?? 0) + y * dest.widthStride
    const srcOffset = (src.offset ?? 0) + y * src.widthStride
    for (let x = 0; x < src.width; ++x) {
      dest.data[dstOffset+x] = src.data[srcOffset+x]!
    }
  }
}

export function extractRect (src: StrideSource, [x, y, width, height]: Rect) {
  let dst
  if (src.data instanceof Uint8ClampedArray) dst = new Uint8ClampedArray(width * height)
  else if (src.data instanceof Uint8Array) dst = new Uint8Array(width * height)
  else if (src.data instanceof Uint16Array) dst = new Uint16Array(width * height)
  else throw new Error(`Unsupported type of ${typeof src.data}`)

  for (let dstY = 0, srcY = y; dstY < height; ++dstY, ++srcY) {
    const dstOffset = dstY * width
    const srcOffset = (src.offset ?? 0) + srcY * src.widthStride
    for (let dstX = 0, srcX = x; dstX < width; ++dstX, ++srcX) {
      dst[dstOffset+dstX] = src.data[srcOffset+srcX]!
    }
  }

  return dst
}
