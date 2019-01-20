const fs = require('fs');

const table = new Int16Array(512)

for(let i = 0; i < 256; ++i) {
	let sin = Math.trunc(Math.sin(i/256 * Math.PI*2) * 0x7FFF)
	if(sin < 0)
		sin += 0x10000

	let cos = Math.trunc(Math.cos(i/256 * Math.PI*2) * 0x7FFF)
	if(cos < 0)
		cos += 0x10000

	table[(i << 1)] = sin
	table[(i << 1) + 1] = cos
}

fs.writeFileSync('sin.bin', table)