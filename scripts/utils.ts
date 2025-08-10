import { utils, distance } from 'image-q'

export function concatenate (...arrays: Uint32Array[]): Uint32Array {
  const totalBytes = arrays.reduce((accumulator, currentValue) => accumulator + currentValue.byteLength, 0)
  const buffer = new ArrayBuffer(totalBytes)
  const concatenated = new Uint32Array(buffer)
  arrays.reduce((valuesWritten, array) => (concatenated.set(array, valuesWritten), valuesWritten + array.length), 0)

  return concatenated
}

function getNearestIndex(palette: utils.Palette, colorDistanceCalculator: distance.AbstractDistanceCalculator, point: utils.Point) {
  const pointArray = palette.getPointContainer().getPointArray()

  let minimalDistance = Number.MAX_VALUE
  let idx = 0

  for (let i = 0, l = pointArray.length; i < l; ++i) {
    const p = pointArray[i];
    if (p === undefined) continue

    const distance = colorDistanceCalculator.calculateRaw(point.r, point.g, point.b, point.a, p.r, p.g, p.b, p.a)

    if (distance < minimalDistance) {
      minimalDistance = distance;
      idx = i
    }
  }

  return idx
}

export function getIndexArray(pointContainer: utils.PointContainer, palette: utils.Palette, distanceCalculator: distance.AbstractDistanceCalculator) {
  const pointArray = pointContainer.getPointArray()
  const paletteIndices = new Uint8ClampedArray(pointArray.length)

  for (let idx = 0, l = pointArray.length; idx < l; ++idx) {
    const point = pointArray[idx]
    if (point === undefined) continue
    paletteIndices[idx] = getNearestIndex(palette, distanceCalculator, point)
  }

  return paletteIndices
}

