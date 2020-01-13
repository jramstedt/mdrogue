const fs = require('fs')
const zlib = require('zlib')
const execa = require('execa')

const FLIPPED_HORIZONTALLY_FLAG = 0x80000000
const FLIPPED_VERTICALLY_FLAG   = 0x40000000
const FLIPPED_DIAGONALLY_FLAG   = 0x20000000
const ID_MASK = ~(FLIPPED_HORIZONTALLY_FLAG | FLIPPED_VERTICALLY_FLAG | FLIPPED_DIAGONALLY_FLAG)

const tmxrasterizer = `${process.env.USERPROFILE}\\Downloads\\tiled-windows-64bit-snapshot\\tmxrasterizer.exe`
const tmxrasterizeroptions = []

const patternSize = 8 // Mega Drive uses 8x8 pixel patterns.

const [,, mapFilename] = process.argv

if (mapFilename === undefined || mapFilename.length === 0) {
  console.error('Tiled map filename missing.')
  return
}

const mapData = JSON.parse(fs.readFileSync(mapFilename, { encoding: 'utf8' }))

const chunkSize = [
  mapData.editorsettings.chunksize.width || 32,
  mapData.editorsettings.chunksize.height || 32,
]
const chunkVolume = chunkSize[0] * chunkSize[1]

const minX = mapData.layers.reduce((min, layer) => Math.min(min, layer.startx || layer.x), Infinity)
const maxX = mapData.layers.reduce((max, layer) => Math.max(max, (layer.startx || layer.x) + layer.width), -Infinity)
const minY = mapData.layers.reduce((min, layer) => Math.min(min, layer.starty || layer.y), Infinity)
const maxY = mapData.layers.reduce((max, layer) => Math.max(max, (layer.starty || layer.y) + layer.height), -Infinity)

const mapPatterns = [
  maxX - minX,
  maxY - minY
]
const mapVolumePatterns = mapPatterns[0] * mapPatterns[1]

const chunks = [
  Math.ceil(mapPatterns[0] / chunkSize[0]),
  Math.ceil(mapPatterns[1] / chunkSize[1])
]

const rawData = new ArrayBuffer(mapVolumePatterns >> 3) // one bit per pattern
const rawType = new ArrayBuffer(mapVolumePatterns >> 1) // nibble per pattern

const collisionData = []
const collisionType = []
for (let chunkY = 0; chunkY < chunks[1]; ++chunkY) {
  const dataRow = collisionData[chunkY] = []
  const typeRow = collisionType[chunkY] = []
  const rowOffset = chunkY * chunks[0]

  for (let chunkX = 0; chunkX < chunks[0]; ++chunkX) {
    const dataOffset = (rowOffset + chunkX) * chunkVolume

    dataRow[chunkX] = new Uint8Array(rawData, dataOffset >> 3, chunkVolume >> 3)
    typeRow[chunkX] = new Uint8Array(rawType, dataOffset >> 1, chunkVolume >> 1)
  }
}

const collisionLayers = mapData.layers.filter(layer => {
  if (layer.type !== 'tilelayer') return false
  if (layer.properties === undefined) return false
  for(const property of layer.properties)
    if(property.name === 'collision' && property.value === true)
      return true

  return false
})

mapData.tilesets.sort((first, second) => first.firstgid - second.firstgid)

for (const layer of collisionLayers) {
  let data;

  if (layer.encoding === 'base64') {
    data = Buffer.from(layer.data, 'base64')

    if (layer.compression === 'zlib')
      data = zlib.inflateSync(data)
    else if(layer.compression === 'gzip')
      data = zlib.gunzipSync(data)
  } else if(layer.encoding === 'csv') {
    console.error('csv not supported.')
  } else {
    console.error('tile objects not supported')
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

      const tileId = getTileId(globalTileId)
      // console.log(realX, realY, globalTileId)

      const patternInChunkPosition = (realY % chunkSize[1]) * chunkSize[0] + (realX % chunkSize[0])

      const typeIndex = patternInChunkPosition >> 1
      const dataIndex = patternInChunkPosition >> 3

      const dataMask = 1 << (7 - (realX & 7))
      const typeShift = (realX & 1) << 4

      const dataChunk = collisionData[chunkY][chunkX]
      const typeChunk = collisionType[chunkY][chunkX]

      const wasSetBefore = dataChunk[dataIndex] & dataMask !== 0

      if (wasSetBefore && typeChunk[typeIndex] !== typeChunk)
        typeChunk[typeIndex] &= 0xF0 >> typeShift
      else
        typeChunk[typeIndex] |= tileId << typeShift
      
      dataChunk[dataIndex] |= dataMask
    }
  }
}

function getTileId(globalId) {
  globalId = globalId & ID_MASK
  let tileId = globalId

  for(let i = 0; i < mapData.tilesets.length; ++i) {
    const firstgid = mapData.tilesets[i].firstgid
    if (firstgid > globalId) break

    tileId = globalId - firstgid
  }

  return tileId
}

fs.writeFileSync('assets/coldata.bin', new DataView(rawData))
fs.writeFileSync('assets/coltype.bin', new DataView(rawType))
