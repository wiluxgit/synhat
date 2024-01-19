// So painfully inconvenient
// https://stackoverflow.com/questions/29325906/can-you-use-raw-webgl-textures-with-three-js
// https://stackoverflow.com/questions/73133566/pixels-are-changing-back-after-putimagedata-with-png

const uploadInputImage = document.getElementById("uploadInputImage")
const canvasSkinPreview = document.getElementById("canvasSkinPreview")
const canvasSkinPreviewCtx = canvasSkinPreview.getContext("webgl2", {preserveDrawingBuffer: true})
const canvasCameraCtx = document.getElementById("camera").getContext("webgl2")

const gl = canvasSkinPreviewCtx

let skinName = "steve.png"
const imageData = new Uint8Array(64*64*4)

MAIN = {}
MAIN.changedUploadImage = async (id2transformOutput, inputEvent) => {
    console.log("MAIN.changedUploadImage")

    const fileInput = inputEvent.target
    if (fileInput.files.length <= 0) {
        alert("No image chosen")
        return
    }

    const fileName = inputEvent.target.files[0]
    const pngbufPromise = new Promise((resolve, reject) => {
        const reader = new FileReader()
        reader.onerror = ((e) => reject(e))
        reader.onload = ((e) => {
            skinName = fileName
            const fileContent = e.target.result
            console.log("MAIN.changedUploadImage>", fileContent)
            resolve(fileContent)
        })
        reader.readAsArrayBuffer(fileName)
    })
    MAIN.loadImage(id2transformOutput, pngbufPromise)
}

MAIN.loadImage = async (id2transformOutput, nullablePngbufPromise) => {
    console.log("MAIN.loadImage")
    let imgageFetch
    if (nullablePngbufPromise !== undefined) {
        imgageFetch = nullablePngbufPromise
    } else {
        skinName = "steve.png"
        imgageFetch = fetch("assets/steve.png", {credentials: 'same-origin'})
            .then((response) => response.arrayBuffer())
    }
    await imgageFetch.then((buf) => loadPngfilebuf(buf))
    await glRetry(MAIN.renderImageNow)
    MAIN.readtransforms(id2transformOutput)
}
function loadPngfilebuf(buf) {
    return new Promise(
        (resolve, reject) => new PngJS.PNG().parse(buf, (error, data) => error ? reject(error) : resolve(data))
    ).then((png) => new Promise(
        (resolve, reject) => {
            if (png.width != 64 || png.height != 64) {
                reject("image is not 64x64")
            }
            // Flip image
            // <Chat GPT>
            for (let y = 0; y < png.height; y++) {
                for (let x = 0; x < png.width; x++) {
                    const newY = png.height - y - 1; // Flip vertically
                    const existingIndex = (y * png.width + x) << 2;
                    const newIndex = (newY * png.width + x) << 2;

                    // Copy RGBA values
                    imageData[existingIndex] = png.data[newIndex];
                    imageData[existingIndex + 1] = png.data[newIndex + 1];
                    imageData[existingIndex + 2] = png.data[newIndex + 2];
                    imageData[existingIndex + 3] = png.data[newIndex + 3];
                }
            }
            // </Chat GPT>
            return resolve()
        }
    ))
}
async function glRetry(func, maxtires=10, retryDelayMs=500) {
    let attempts = 0
    let err = undefined
    while (true) {
        gl.getError() // flush error buffer
        func()
        await new Promise(r => setTimeout(r, 100));
        err = gl.getError()
        if (err == gl.NO_ERROR) {
            return
        } else {
            attempts++
            if (attempts >= maxtires) {
                break
            }
            console.warn(`glRetry> WEBGL error: ${err}, retrying (attempt ${attempts})`)
            await new Promise(r => setTimeout(r, retryDelayMs));
        }
    }
    const errNames = {}
    errNames[gl.INVALID_ENUM] = "gl.INVALID_ENUM"
    errNames[gl.INVALID_VALUE] = "gl.INVALID_VALUE"
    errNames[gl.INVALID_OPERATION] = "gl.INVALID_OPERATION"
    errNames[gl.INVALID_FRAMEBUFFER_OPERATION] = "gl.INVALID_FRAMEBUFFER_OPERATION"
    errNames[gl.OUT_OF_MEMORY] = "gl.OUT_OF_MEMORY"
    errNames[gl.CONTEXT_LOST_WEBGL] = "gl.CONTEXT_LOST_WEBGL"
    const errstr = `glRetry> Unsolveable WEBGL error: ${err} (${errNames[err]}). ${attempts} where made.`
    console.error(errstr)
    alert(errstr)
}

MAIN.renderImage = () => {
    console.log("MAIN.renderImage")
    MAIN.debounce(MAIN.renderImageNow)()
}
MAIN.renderImageNow = () => {
    const firstbyte = [0,1,2,3].map((x) => imageData[getByteOffset(0,0,x)])
    const dataSquare = [...Array(8).keys()].map((y) =>
        [...Array(8).keys()].map((x) =>
            hexstr([0,1,2,3].map((c) => imageData[getByteOffset(x,y,c)]))
        )
    )
    console.log("MAIN.renderImageNow", firstbyte, dataSquare)

    canvasSkinPreviewCtx.texImage2D(
        gl.TEXTURE_2D, 0, gl.RGBA, 64, 64, 0,
        gl.RGBA, gl.UNSIGNED_BYTE,
        imageData
    )
    canvasCameraCtx.texImage2D(
        gl.TEXTURE_2D, 0, gl.RGBA, 64, 64, 0,
        gl.RGBA, gl.UNSIGNED_BYTE,
        imageData
    )

    document
        ?.getElementById("canvasUVPreview")
        ?.getContext("2d")
        ?.drawImage(canvasSkinPreview, 0, 0)
}
MAIN.newDefaultTransformDictionary = () => {
    const d = {}
    const _ = [...Array(72).keys()].map((i) => d[i] = [])
    return d
}

function hexstr(buf, extra="") {
    return [...buf].map((b) => b.toString(16).padStart(2, "0").toUpperCase()).join("_")
}
function logHexAndBin(buf, extra="") {
    const binStr = [...buf].map((b) => b.toString(2).padStart(8, "0")).join("_");
    const hexStr = [...buf].map((b) => b.toString(16).padStart(2, "0").toUpperCase()).join("_")
    console.log(`0b${binStr} | 0x${hexStr} (len=${buf.length}) ${extra}`);
}
function getFaceOperationEntryPos(faceId) {
    let c = faceId % 4;
    let temp = 2 + ((faceId / 4) >> 0)
    let x = temp % 8
    let y = (temp / 8) >> 0
    return [x, y, c]
}
function getTransformPosition(transform_arugment_index) {
    let temp = (8*2+4) + transform_arugment_index;
    let x = temp % 8;
    let y = (temp / 8) >> 0;
    return [x, y]
}
function getByteOffset(x, y, c=0) {
    y = 63-y
    return 4 * (y * 64 + x) + c;
}

MAIN.debounce = (func, timeout = 500) => {
    let timer;
    return (...args) => {
      clearTimeout(timer);
      timer = setTimeout(() => { func.apply(this, args); }, timeout);
    };
}

MAIN.downloadCanvas = () => {
    const png = new PngJS.PNG({ width: 64, height: 64, filterType: -1})
    // <ChatGPT>
    const flippedData = []
    for (let y = png.height - 1; y >= 0; y--) {
        for (let x = 0; x < png.width; x++) {
            const idx = (png.width * y + x) << 2;
            flippedData.push(imageData[idx], imageData[idx + 1], imageData[idx + 2], imageData[idx + 3]);
        }
    }
    png.data = new Uint8Array(flippedData);
    // </ChatGPT>
    const blob = new Blob([PngJS.PNG.sync.write(png)], { type: 'image/png' });
    FileSaver.saveAs(blob, 'output64x64.png');
}

MAIN.readtransforms = (id2transformOutput) => {
    faceId2typeAndOffset = {}
    // read lookup tables
    for (const index of [...Array(72).keys()]) {
        const [x,y,c] = getFaceOperationEntryPos(index)
        const offset = getByteOffset(x,y,c)
        const data = imageData[offset]
        if (data == 0 || data == 0xff) {
            continue
        }
        const buf = new Uint8Array(1)
        buf[0] = imageData[offset]
        const parse = MAIN.faceOperationParser.parse(buf)
        faceId2typeAndOffset[index] = parse
        console.log(`readtransforms> F[${x},${y},${c}] = ${data}`, parse)
    }
    if(Object.keys(faceId2typeAndOffset).length == 72) {
        // TODO: make good
        return
    }

    for (let [faceindex, v] of Object.entries(faceId2typeAndOffset)) {
        const transformType = v.transform_type
        const argumentIndex = v.transform_argument_index

        id2transformOutput[faceindex] = []

        const [x, y] = getTransformPosition(argumentIndex)
        const transformOffset = getByteOffset(x,y)

        const transformBuf = new Uint8Array(4)
        for (let i of [0,1,2,3]) {
            transformBuf[3-i] = imageData[transformOffset+i] //fixes endianness
        }
        const parser = MAIN.transform_parsers[transformType]
        const parse = parser.parse(transformBuf)

        console.log("readtransforms> parse:", parse)
        id2transformOutput[faceindex].push({
            "face":`${faceindex}`,
            "id":1,
            "type":transformType,
            "data":parse
        })

        // TODO continued
    }
}
MAIN.writeTransformsAndRender = (id2transform) => {
    console.log("MAIN.writeTransformsAndRender")

    const serializedFaceEntries = new Uint8Array(72)
    const serializedTransforms = new Uint32Array(44)

    // fill serializedFaceEntries, serializedTransforms
    let transformIndex = 1
    for ([faceId, faceTransfroms] of Object.entries(id2transform)){
        if (faceTransfroms.length === 0) {
            continue
        }

        // next of last entry is always 0
        let nextSerialized = 0

        // TODO: sort transforms
        for (let faceTransfrom of [...faceTransfroms].reverse()) {
            const ttype = faceTransfrom.type

            // Create Transforms entry
            const transform = {...faceTransfrom.data, ...{"next": nextSerialized}}
            const transformParser = MAIN.transform_parsers[ttype];
            const tfBuf = transformParser.encode(transform);
            serializedTransforms[transformIndex] = tfBuf.readInt32LE(0)
            logHexAndBin(tfBuf, `= serializedTransforms[${transformIndex}]`);

            // Create Lookup entry
            const faceOperation = {
                "transform_type": ttype,
                "transform_argument_index": transformIndex,
            }
            nextSerialized = MAIN.faceOperationParser.encode(faceOperation)[0]

            transformIndex++
        }

        // First facetransform should be used in lookup.
        serializedFaceEntries[faceId] = nextSerialized
        console.log(`${nextSerialized} = serializedFaceEntries[${faceId}]`);
    }

    // write lookup tables
    for (let [index, int] of serializedFaceEntries.entries()) {
        const [x,y,c] = getFaceOperationEntryPos(index)

        const offset = getByteOffset(x,y,c)
        imageData[offset] = int

        if(int != 0) {
            console.log(`F pos=${index} offset=${offset}, x=${x}, y=${y}, c=${c} value=0x${int.toString(16)}`)
        }
    }

    // write transforms
    for (let [index, int] of serializedTransforms.entries()) {
        const [x, y] = getTransformPosition(index)

        const offset = getByteOffset(x,y)
        imageData[offset+0] = (int >> 24) & 0xff
        imageData[offset+1] = (int >> 16) & 0xff
        imageData[offset+2] = (int >> 8) & 0xff
        imageData[offset+3] = (int >> 0) & 0xff

        if(int != 0) {
            const hexstr = [...Array(4).keys()].map(
                (x) => imageData[offset+x].toString(16).padStart(2, "0")
            ).join("|")
            console.log(`T pos=${index} offset=${offset}, x=${x}, y=${y} value=${hexstr}`)
        }
    }

    MAIN.renderImage()
}

MAIN.enums = {
    transform_type:{
        displacement: 0,
        uv_crop: 1,
        uv_offset: 2,
        special: 3,
    },

    snap: {
        true: 1,
        false: 0,
    },

    sign: {
        positive: 0,
        negative: 1,
    },

    asym_spec: {
        no: 0,
        yes: 1,
    },

    asym_sign: {
        positive: 0,
        negative: 1,
    },

    asym_special_mode:{
        flip_outer: 0,
        flip_inner: 1,
    },

    asym_edge: {
        top: 0,
        bottom: 1,
        right: 2,
        left: 3,
    },
}

MAIN.faceOperationParser = (
    new BinaryParser.Parser()
        .endianess("little")
        .encoderSetOptions({bitEndianess: true})
        .bit6("transform_argument_index")
        .bit2("transform_type")
)

MAIN.default_transform = {}
MAIN.transform_parsers = {}
// ====================================================
MAIN.transform_parsers[MAIN.enums.transform_type.displacement] = (
    new BinaryParser.Parser()
        .endianess("little")
        .encoderSetOptions({bitEndianess: true})
        .bit6("global_displacement")
        .bit1("snap")
        .bit1("sign")
        .bit6("asym_displacement")
        .bit1("asym_spec")
        .bit1("asym_sign")
        .bit2("asym_edge")
        .bit6("__filler__")
        .bit8("next")
)
MAIN.default_transform[MAIN.enums.transform_type.displacement] = {
    global_displacement: 0,
    snap: MAIN.enums.snap.false,
    sign: MAIN.enums.sign.positive,
    asym_displacement: 0,
    asym_sign: MAIN.enums.asym_sign.positive,
    asym_spec: MAIN.enums.asym_spec.no,
    asym_edge: MAIN.enums.asym_edge.top,
}

// ====================================================
MAIN.transform_parsers[MAIN.enums.transform_type.uv_offset] = (
    new BinaryParser.Parser()
        .endianess("little")
        .encoderSetOptions({bitEndianess: true})
        .bit6("uv_x_max")
        .bit2("uv_y_min_0")
        .bit6("uv_x_min")
        .bit2("uv_y_min_1")
        .bit6("uv_y_max")
        .bit2("uv_y_min_2")
        .bit8("next")
)
MAIN.default_transform[MAIN.enums.transform_type.uv_offset] = {
    uv_x_max: 0,
    uv_x_min: 0,
    uv_y_max: 0,
    uv_y_min_0: 0,
    uv_y_min_1: 0,
    uv_y_min_2: 0,
}

// ====================================================
MAIN.transform_parsers[MAIN.enums.transform_type.uv_crop] = (
    new BinaryParser.Parser()
        .endianess("little")
        .encoderSetOptions({bitEndianess: true})
        .bit4("crop_top")
        .bit4("crop_bot")
        .bit4("crop_right")
        .bit4("crop_left")
        .bit1("snap_x")
        .bit1("snap_y")
        .bit1("__filler1__")
        .bit1("__filler2__")
        .bit4("__filler3__")
        .bit8("next")
)
MAIN.default_transform[MAIN.enums.transform_type.uv_crop] = {
    crop_top: 0,
    crop_bot: 0,
    crop_right: 0,
    crop_left: 0,
    snap_x: 0,
    snap_y: 0,
    mirr_x: 0,
    mirr_y: 0,
}

// ====================================================
MAIN.transform_parsers[MAIN.enums.transform_type.special] = (
    new BinaryParser.Parser()
        .endianess("little")
        .encoderSetOptions({bitEndianess: true})
        .bit1("top_snap_clip_uv")
        .bit1("bot_snap_clip_uv")
        .bit1("right_snap_clip_uv")
        .bit1("left_snap_clip_uv")
        .bit4("__filler__")
        .bit8("__filler2__")
        .bit8("__filler3__")
        .bit8("next")
)
MAIN.default_transform[MAIN.enums.transform_type.special] = {
    top_snap_clip_uv: 0,
    bot_snap_clip_uv: 0,
    left_snap_clip_uv: 0,
    right_snap_clip_uv: 0,
}

MAIN.MakeExprToCreateSignedTwoWayBinding = (signedDotPath, absDotPath, isNegativeDotPath) => {
    return `
    $watch(\"${signedDotPath}\", (value) => {
        if (typeof ${signedDotPath} !== 'undefined') {
            ${absDotPath} = Math.abs(${signedDotPath})
            ${isNegativeDotPath} = ${signedDotPath} < 0
        }
    })
    $watch(\"${absDotPath}\", (value) => {
        if (typeof ${signedDotPath} !== 'undefined') {
            ${signedDotPath} = ${absDotPath} * (${isNegativeDotPath} ? -1 : 1)
        }
    })
    $watch(\"${isNegativeDotPath}\", (value) => {
        if (typeof ${signedDotPath} !== 'undefined') {
            ${signedDotPath} = ${absDotPath} * (${isNegativeDotPath} ? -1 : 1)
        }
    })
    ${signedDotPath} = ${absDotPath} * (${isNegativeDotPath} ? -1 : 1)
    `
}
MAIN.MakeExprToCreate3x2BitsTwoWayBinding = (fullvalue, bit01, bit23, bit45) => {
    //[bit01, bit23, bit45] = bitarr
    return `
    const lsbyte = 0b00000011
    const bitchange = (value) => {
        if (typeof ${fullvalue} !== 'undefined') {
            //console.log("updated bitarr=", ${bit01}, ${bit23}, ${bit45})
            ${fullvalue} = (${bit01} << 4) | (${bit23} << 2) | (${bit45} << 0)
        }
    }
    $watch(\"${fullvalue}\", (value) => {
        if (typeof ${fullvalue} !== 'undefined') {
            //console.log("updated fullvalue=", ${fullvalue})
            ${bit01} = lsbyte & (${fullvalue} >> 4)
            ${bit23} = lsbyte & (${fullvalue} >> 2)
            ${bit45} = lsbyte & (${fullvalue} >> 0)
        }
    })
    $watch(\"${bit01}\", bitchange)
    $watch(\"${bit23}\", bitchange)
    $watch(\"${bit45}\", bitchange)
    ${fullvalue} = (${bit01} << 4) | (${bit23} << 2) | (${bit45} << 0)
    `
}

MAIN.id2uvs = {
    0: [[16, 8], [24, 16]],
    6: [[28, 20], [32, 32]],
    12: [[40, 52], [44, 64]],
    18: [[48, 20], [52, 32]],
    24: [[24, 52], [28, 64]],
    30: [[8, 20], [12, 32]],
    36: [[48, 8], [56, 16]],
    42: [[8, 36], [12, 48]],
    48: [[8, 52], [12, 64]],
    54: [[56, 52], [60, 64]],
    60: [[48, 36], [52, 48]],
    66: [[28, 36], [32, 48]],
    1: [[0, 8], [8, 16]],
    7: [[16, 20], [20, 32]],
    13: [[32, 52], [36, 64]],
    19: [[40, 20], [44, 32]],
    25: [[16, 52], [20, 64]],
    31: [[0, 20], [4, 32]],
    37: [[32, 8], [40, 16]],
    43: [[0, 36], [4, 48]],
    49: [[0, 52], [4, 64]],
    55: [[48, 52], [52, 64]],
    61: [[40, 36], [44, 48]],
    67: [[16, 36], [20, 48]],
    2: [[8, 0], [16, 8]],
    8: [[20, 16], [28, 20]],
    14: [[36, 48], [40, 52]],
    20: [[44, 16], [48, 20]],
    26: [[20, 48], [24, 52]],
    32: [[4, 16], [8, 20]],
    38: [[40, 0], [48, 8]],
    44: [[4, 32], [8, 36]],
    50: [[4, 48], [8, 52]],
    56: [[52, 48], [56, 52]],
    62: [[44, 32], [48, 36]],
    68: [[20, 32], [28, 36]],
    3: [[16, 0], [24, 8]],
    9: [[28, 16], [36, 20]],
    15: [[40, 48], [44, 52]],
    21: [[48, 16], [52, 20]],
    27: [[24, 48], [28, 52]],
    33: [[8, 16], [12, 20]],
    39: [[48, 0], [56, 8]],
    45: [[8, 32], [12, 36]],
    51: [[8, 48], [12, 52]],
    57: [[56, 48], [60, 52]],
    63: [[48, 32], [52, 36]],
    69: [[28, 32], [36, 36]],
    4: [[8, 8], [16, 16]],
    10: [[20, 20], [28, 32]],
    16: [[36, 52], [40, 64]],
    22: [[44, 20], [48, 32]],
    28: [[20, 52], [24, 64]],
    34: [[4, 20], [8, 32]],
    40: [[40, 8], [48, 16]],
    46: [[4, 36], [8, 48]],
    52: [[4, 52], [8, 64]],
    58: [[52, 52], [56, 64]],
    64: [[44, 36], [48, 48]],
    70: [[20, 36], [28, 48]],
    5: [[24, 8], [32, 16]],
    11: [[32, 20], [40, 32]],
    17: [[44, 52], [48, 64]],
    23: [[52, 20], [56, 32]],
    29: [[28, 52], [32, 64]],
    35: [[12, 20], [16, 32]],
    41: [[56, 8], [64, 16]],
    47: [[12, 36], [16, 48]],
    53: [[12, 52], [16, 64]],
    59: [[60, 52], [64, 64]],
    65: [[52, 36], [56, 48]],
    71: [[32, 36], [40, 48]],
}