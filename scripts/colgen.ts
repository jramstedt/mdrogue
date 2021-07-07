import fs from 'fs'
import { resolve } from 'path'
import zlib from 'zlib'
import execa from 'execa'
import { Image, Canvas, createImageData } from 'canvas'
import RgbQuant from 'rgbquant'
import { Group, ID_MASK, isGroup, isTileLayer, Layer, TiledMap, TileLayer } from './tiled'

function getTileIndexInTileset(globalId: number): number {
  globalId = globalId & ID_MASK
  let tileId = globalId

  for(let i = 0; i < mapData.tilesets.length; ++i) {
    const firstgid = mapData.tilesets[i].firstgid
    if (firstgid > globalId) break

    tileId = globalId - firstgid
  }

  return tileId
}

const patternSize = 8 // Mega Drive uses 8x8 pixel patterns.

const [,, mapFilename, targetDirectory] = process.argv

if (mapFilename === undefined || mapFilename.length === 0) {
  console.error('Tiled map filename missing.')
  process.exit(1)
}

if (targetDirectory === undefined || targetDirectory.length === 0) {
  console.error('Target directory missing.')
  process.exit(2)
}

const mapData = JSON.parse(fs.readFileSync(mapFilename, { encoding: 'utf8' })) as TiledMap

const chunkSize = [
  mapData.editorsettings?.chunksize?.width ?? 32,
  mapData.editorsettings?.chunksize?.height ?? 32,
]
const chunkVolume = chunkSize[0] * chunkSize[1]

const tileLayers = mapData.layers.filter(layer => isTileLayer(layer)) as TileLayer[]

const minX = tileLayers.reduce((min, layer) => Math.min(min, layer.startx ?? layer.x), Infinity)
const maxX = tileLayers.reduce((max, layer) => Math.max(max, (layer.startx ?? layer.x) + layer.width), -Infinity)
const minY = tileLayers.reduce((min, layer) => Math.min(min, layer.starty ?? layer.y), Infinity)
const maxY = tileLayers.reduce((max, layer) => Math.max(max, (layer.starty ?? layer.y) + layer.height), -Infinity)

const mapPatterns = [
  maxX - minX,
  maxY - minY
]
const mapPatternsVolume = mapPatterns[0] * mapPatterns[1]

const chunks = [
  Math.ceil(mapPatterns[0] / chunkSize[0]),
  Math.ceil(mapPatterns[1] / chunkSize[1])
]

const rawData = new ArrayBuffer(mapPatternsVolume >>> 3) // one bit per pattern
const rawType = new ArrayBuffer(mapPatternsVolume >>> 1) // nibble per pattern

const collisionData = [] as DataView[][]
const collisionType = [] as DataView[][]
for (let chunkY = 0; chunkY < chunks[1]; ++chunkY) {
  const dataRow = collisionData[chunkY] = [] as DataView[]
  const typeRow = collisionType[chunkY] = [] as DataView[]
  const rowOffset = chunkY * chunks[0]

  for (let chunkX = 0; chunkX < chunks[0]; ++chunkX) {
    const dataOffset = (rowOffset + chunkX) * chunkVolume

    dataRow[chunkX] = new DataView(rawData, dataOffset >>> 3, chunkVolume >>> 3)
    typeRow[chunkX] = new DataView(rawType, dataOffset >>> 1, chunkVolume >>> 1)
  }
}

const collisionLayers = mapData.layers.filter(layer => {
  if (!isTileLayer(layer)) return false

  if (layer.properties === undefined) return false
  for(const property of layer.properties)
    if(property.name === 'collision' && property.value === true)
      return true

  return false
}) as TileLayer[]

mapData.tilesets.sort((first, second) => first.firstgid - second.firstgid)

for (const layer of collisionLayers) {
  let data: Buffer

  if (layer.encoding === 'base64') {
    if (typeof layer.data !== 'string') continue

    data = Buffer.from(layer.data, 'base64')

    if (layer.compression === 'zlib')
      data = zlib.inflateSync(data)
    else if(layer.compression === 'gzip')
      data = zlib.gunzipSync(data)
    //else if(layer.compression === 'zstd')
    //  data = zstd.decompressSync(data)
    else
      throw new Error(`compression '${layer.compression}' not supported`)
  } else if(layer.encoding === 'csv') {
    throw new Error('csv not supported.')
  } else {
    throw new Error('tile objects not supported.')
    //data = Buffer.from(layer.data)
  }

  const dataView = new Uint32Array(data.buffer)

  for (let y = 0; y < layer.height; ++y) {
    const realY = layer.y + y
    const chunkY = Math.trunc(realY / chunkSize[1])

    for (let x = 0; x < layer.width; ++x) {
      const globalTileId = dataView[y * layer.width + x]
      if (globalTileId === 0) continue  // empty tile

      const realX = layer.x + x
      const chunkX = Math.trunc(realX / chunkSize[0])

      const tileIndex = getTileIndexInTileset(globalTileId)
      // console.log(realX, realY, globalTileId)

      const patternInChunkPosition = (realY % chunkSize[1]) * chunkSize[0] + (realX % chunkSize[0])

      const typeByteOffset = patternInChunkPosition >>> 1
      const dataByteOffset = (patternInChunkPosition >>> 5) << 2

      const dataMask = 1 << (realX & 31)
      const typeShift = (realX & 1) * 4
      const typeMask = 0xF0 >>> typeShift

      const dataChunk = collisionData[chunkY][chunkX]
      const typeChunk = collisionType[chunkY][chunkX]

      const wasSetBefore = (dataChunk.getUint32(dataByteOffset, false) & dataMask) !== 0

      const shiftedTileIndex = tileIndex << typeShift
      if (wasSetBefore && (typeChunk.getUint8(typeByteOffset) & typeMask) !== shiftedTileIndex)
        typeChunk.setUint8(typeByteOffset, typeChunk.getUint8(typeByteOffset) | typeMask)
      else
        typeChunk.setUint8(typeByteOffset, typeChunk.getUint8(typeByteOffset) | shiftedTileIndex)
      
      dataChunk.setUint32(dataByteOffset, dataChunk.getUint32(dataByteOffset, false) | dataMask, false)
    }
  }
}

function hideParams(...layers: Layer[]): string[] {
  return layers.map(layer => `--hide-layer "${layer.name}"`)
}
function filterLayers (map: TiledMap, name: string): Layer[] {
  const layers = [] as Layer[]

  const filterLayers = (group: Group, name: string): Layer[] => {
    const matchingLayers = [] as Layer[]
    for (const layer of group.layers) {
      if (isGroup(layer)) matchingLayers.push(...filterLayers(layer, name))
      else if (layer.name.toLocaleLowerCase().includes(name)) matchingLayers.push(layer)
    }
    return matchingLayers
  }

  for (const layer of map.layers) {
    if (isGroup(layer)) layers.push(...filterLayers(layer, name))
    else if (layer.name.toLocaleLowerCase().includes(name)) layers.push(layer)
  }

  return layers
}

const paramCollisionLayers = filterLayers(mapData, 'collision')
const planeALayers = filterLayers(mapData, 'plane a')
const planeBLayers = filterLayers(mapData, 'plane b')

fs.writeFileSync(resolve(targetDirectory, 'col.data.bin'), new DataView(rawData))
fs.writeFileSync(resolve(targetDirectory, 'col.type.bin'), new DataView(rawType))

const tmxrasterizer = `${process.env['USERPROFILE']}\\Downloads\\tiled-windows-64bit-snapshot\\tmxrasterizer.exe`
const tmxrasterizeroptions = ['--no-smoothing']

const megaDriveLadder = [0x00, 0x34, 0x57, 0x74, 0x90, 0xAC, 0xCE, 0xFF]
const palette: [r: number, g: number, b: number][] = []
for (let r = 0; r <= 0b111; ++r) {
  for (let g = 0; g <= 0b111; ++g) {
    for (let b = 0; b <= 0b111; ++b) {
      palette.push([
        megaDriveLadder[r], 
        megaDriveLadder[g], 
        megaDriveLadder[b]
      ])
    }
  }
}

execa(tmxrasterizer, [...tmxrasterizeroptions, ...hideParams(...planeALayers, ...planeBLayers), mapFilename, resolve(targetDirectory, 'collision.png')], { windowsVerbatimArguments: true })
  .then(async ({ stdout, stderr }) => { if (stderr.length !== 0) return console.error(new Error(stderr)) })

execa(tmxrasterizer, [...tmxrasterizeroptions, ...hideParams(...planeALayers, ...paramCollisionLayers), mapFilename, resolve(targetDirectory, 'planeB.png')], { windowsVerbatimArguments: true })
  .then(async ({ stdout, stderr }) => { if (stderr.length !== 0) return console.error(new Error(stderr)) })
  .then(() => {
    fs.readFile(resolve(targetDirectory, 'planeB.png'), (err, data) => {
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
      fs.writeFileSync(resolve(targetDirectory, 'planeBreduced.png'), dataBuffer)
      // #endregion
  
      const indexedImage = quant.reduce(pixelArray, 2)

      const tilesWidth = canvas.width >>> 5
      const tilesHeight = canvas.height >>> 5
      
      const patterns: { normal: Uint32Array, flipped: Uint32Array }[] = []
      const tiles: Uint16Array[] = []

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
          const tileIndex = (y >>> 5) * tilesWidth + (x >>> 5)
          const patternIndex = ((y >>> 3) % 32) * 32 + ((x >>> 3) % 32)

          const tile = tiles[tileIndex] ??= new Uint16Array(32*32)

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

      console.log(patterns.length)

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

      fs.writeFileSync(resolve(targetDirectory, 'planeB.bin'), megaDrivePalette)
      fs.writeFileSync(resolve(targetDirectory, 'palette.bin'), megaDrivePalette)

      // 4 bits per pixel, 2 pixels per byte
      // word per row
      // long per pattern

      // patterns 01234567 * 8

      // PCCV HAAA AAAA AAAA
  })
})

execa(tmxrasterizer, [...tmxrasterizeroptions, ...hideParams(...planeBLayers, ...paramCollisionLayers), mapFilename, resolve(targetDirectory, 'planeA.png')], { windowsVerbatimArguments: true })
  .then(async ({ stdout, stderr }) => { if (stderr.length !== 0) throw new Error(stderr) })
