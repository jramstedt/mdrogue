import { writeFile } from 'node:fs/promises'

const [, , targetFilename] = process.argv

if (targetFilename === undefined || targetFilename.length === 0) {
  console.error('Target filename missing.')
  process.exit(1)
}

const table = new DataView(new ArrayBuffer(256*2*2))

for(let i = 0; i < 256; ++i) {
  let sin = Math.trunc(Math.sin(i/256 * Math.PI*2) * 0x7FFF)
  let cos = Math.trunc(Math.cos(i/256 * Math.PI*2) * 0x7FFF)
  
  table.setInt16(i << 2, sin, false)
  table.setInt16((i << 2) + 2, cos, false)
}

await writeFile(targetFilename, table)