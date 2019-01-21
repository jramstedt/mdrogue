const fs = require('fs');

const table = new DataView(new ArrayBuffer(256*2*2))

for(let i = 0; i < 256; ++i) {
	let sin = Math.trunc(Math.sin(i/256 * Math.PI*2) * 0x7FFF)
	let cos = Math.trunc(Math.cos(i/256 * Math.PI*2) * 0x7FFF)
	
	table.setInt16(i << 2, sin, false)
	table.setInt16((i << 2) + 2, cos, false)
}

fs.writeFileSync('assets/sin.bin', table)