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

const minX = mapData.layers.reduce((min, layer) => Math.min(min, layer.startx || layer.x), Infinity)
const maxX = mapData.layers.reduce((max, layer) => Math.max(max, (layer.startx || layer.x) + layer.width), -Infinity)
const minY = mapData.layers.reduce((min, layer) => Math.min(min, layer.starty || layer.y), Infinity)
const maxY = mapData.layers.reduce((max, layer) => Math.max(max, (layer.starty || layer.y) + layer.height), -Infinity)

const chunks = [
  Math.ceil((maxX - minX) / chunkSize[0]),
  Math.ceil((maxY - minY) / chunkSize[1])
]

const collisionData = []
const collisionType = []
for (let chunkY = 0; chunkY < chunks[1]; ++chunkY) {
  const dataRow = collisionData[chunkY] = []
  const typeRow = collisionType[chunkY] = []
  for (let chunkX = 0; chunkX < chunks[0]; ++chunkX) {
    dataRow[chunkX] = new Uint8Array((chunkSize[0] * chunkSize[1]) >> 3) // one bit per pattern
    typeRow[chunkX] = new Uint8Array((chunkSize[0] * chunkSize[1]) >> 1) // nibble per pattern
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

  const dataView = new DataView(data.buffer)

  const rowBytes = layer.width << 2
  for (let y = 0; y < layer.height; ++y) {
    const realY = layer.y + y
    const chunkY = Math.trunc(realY / chunkSize[1])
    for (let x = 0; x < layer.width; ++x) {
      const globalTileId = dataView.getUint32(y * rowBytes + (x << 2), true)
      if (globalTileId === 0) continue  // empty tile

      const realX = layer.x + x
      const chunkX = Math.trunc(realX / chunkSize[0])

      const tileId = getTileId(globalTileId)
      // console.log(realX, realY, globalTileId)

      // TODO check previous value, if set and not 0, set as 0

      const dataChunk = collisionData[chunkY][chunkX]
      dataChunk[y * (layer.width >> 3) + x >> 3] |= 1 << (x & 7)

      const typeChunk = collisionType[chunkY][chunkX]
      typeChunk[y * (layer.width >> 1) + x >> 1] = tileId << ((tileId & 1) << 2)
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

// fs.writeFileSync('assets/sincos.bin', table)