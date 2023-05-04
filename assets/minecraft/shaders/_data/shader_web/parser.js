const fromHexString = (hexString) =>
  Uint8Array.from(hexString.match(/.{1,2}/g).map((byte) => parseInt(byte, 16)));

function init() {
    console.log("Yo dawg")
    const Parser = BinaryParser.Parser;

    const parserDisplacement = new Parser()
        .endianness("big")
        .bit4("TRANSFROM_TYPE")
        .bit1("FLAG_DISP_NEGATIVE")
        .bit1("FLAG_DISP_ASYM_NEGATIVE")
        .bit1("FLAG_DISP_OPPOSING_SNAP")
        .bit1("null")
        .bit6("DISP_OFFSET")
        .bit2("DISP_ASYM_TYPE")
        .bit6("DISP_ASYM_OFFSET")
        .bit2("DISP_ASYM_DIRECTION")
        .uint8("Continue");

    const buf = fromHexString("40000000");
    console.log(buf)
    console.log(parserDisplacement.parse(buf));
}

init()