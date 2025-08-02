// So painfully inconvenient
// https://stackoverflow.com/questions/29325906/can-you-use-raw-webgl-textures-with-three-js
// https://stackoverflow.com/questions/73133566/pixels-are-changing-back-after-putimagedata-with-png

const uploadInputImage = document.getElementById("uploadInputImage")
const canvasSkinPreview = document.getElementById("canvasSkinPreview")
const canvasSkinPreviewCtx = canvasSkinPreview.getContext("webgl2", {preserveDrawingBuffer: true})
const canvasCameraCtx = document.getElementById("camera").getContext("webgl2")

// Temp, exists to access gl enums
const gl = canvasSkinPreviewCtx

// Global BGRA??? buffer for storing the extmodel skin file
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
        imgageFetch = fetch("assets/examples/herbex.png", {credentials: 'same-origin'})
            .then((response) => response.arrayBuffer())
    }
    await imgageFetch.then((buf) => loadPngfilebuf(buf))
    await glRetry(MAIN.renderImageNow)
    MAIN.readTransforms(id2transformOutput)
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

            // If not an extmodel skin init it
            const isExtModel = imageData[getByteOffset(0,0,0)] == 0xda && imageData[getByteOffset(0,0,1)] == 0x67
            if (!isExtModel) {
                for (const y of [...Array(8).keys()]) {
                    for (const x of [...Array(8).keys()]) {
                        imageData[getByteOffset(x, y, 0)] = 0xFF;
                        imageData[getByteOffset(x, y, 1)] = 0xFF;
                        imageData[getByteOffset(x, y, 2)] = 0xFF;
                        imageData[getByteOffset(x, y, 3)] = 0xFF;

                        imageData[getByteOffset(x + 24, y, 0)] = 0xFF;
                        imageData[getByteOffset(x + 24, y, 1)] = 0xFF;
                        imageData[getByteOffset(x + 24, y, 2)] = 0xFF;
                        imageData[getByteOffset(x + 24, y, 3)] = 0xFF;
                    }
                }
                imageData[getByteOffset(0,0,0)] = 0xda
                imageData[getByteOffset(0,0,1)] = 0x67
                imageData[getByteOffset(0,0,2)] = 0x00
            }

            return resolve()
        }
    ))
}

/**
 * Runs a synchronous WebGL function repeatedly until it succeeds without errors.
 * There does not appear to exist a way to hook errors so i must poll for them
 *
 * @param {() => void} func - The WebGL function to execute that may produce errors.
 * @param {number} [maxtires=10] - Maximum number of retry attempts before giving up.
 * @param {number} [retryDelayMs=500] - Delay in milliseconds between retry attempts.
 * @returns {Promise<void>} Resolves when the function executes without a WebGL error,
 * or rejects after exhausting retries (alerts user on failure).
 */
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
    const errstr = `glRetry> Unsolveable WEBGL error: ${err} (${errNames[err]}). ${attempts} where made. Try reloading the tab`
    console.error(errstr)
    alert(errstr)
}

MAIN.renderImage = () => {
    console.log("MAIN.renderImage")
    MAIN.debounce(MAIN.renderImageNow)()
}
MAIN.renderImageNow = () => {
    const dataSquare = [...Array(8).keys()].map((y) =>
        [...Array(8).keys()].map((x) =>
            hexstr([0,1,2,3].map((c) => imageData[getByteOffset(x,y,c)]))
        )
    )
    console.log("MAIN.renderImageNow", dataSquare)

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
    console.log(`0b${binStr} | 0x${hexStr} (len=${buf.length})`, extra);
}
function getByteOffset_index(faceId) {
    const rgbaIndex = Math.floor(faceId % 3) << 0;
    const pixelIndex = Math.floor(faceId / 3) << 0;
    const x = Math.floor((pixelIndex + 8) % 8) << 0;
    const y = Math.floor((pixelIndex + 8) / 8) << 0;
    return getByteOffset(x,y,rgbaIndex)
}
function getByteOffset_transform(transformIndex) {
    const temp = 32 + transformIndex;
    let x = Math.floor(temp % 8) << 0;
    let y = Math.floor(temp / 8) << 0;
    if (y >= 8) {
        x += 24;
        y -= 8;
    }
    return getByteOffset(x,y)
}

/**
 * @param {number} x  x coord (from top left)
 * @param {number} y  y coord (from top left)
 * @param {number} [c=0] color
 * @returns {number} Offset in the imdageData matrix
 */
function getByteOffset(x, y, c=0) {
    y = 63-y
    return 4 * (y * 64 + x) + c;
}

/**
 * Serializes a 3-byte Uint8Array [B,G,R] into a 32-bit unsigned integer with A=0xFF.
 * Format: 0xRRGGBBAA (Red is the highest byte, Alpha in the lowest).
 *
 * @param {Uint8Array} uInt8Array - A 3-byte Uint8Array representing RGB color.
 * @returns {number} - A 32-bit unsigned integer in RGBA format.
 */
function serialize3BytesToRGBA(uInt8Array) {
    if (!(uInt8Array instanceof Uint8Array) || uInt8Array.length !== 3) {
        throw new Error("Expected Uint8Array of length 3");
    }
    const r = uInt8Array[2];
    const g = uInt8Array[1];
    const b = uInt8Array[0];
    const a = 0xFF;
    return (r << 24) | (g << 16) | (b << 8) | a;
}

/**
 * Extract a single Uint8Array [R, G, B] from a Uint8Array [B, G, R, A, ...]
 *
 * @param {Uint8Array} array - The input BGRA-formatted Uint8Array
 * @param {number} arrayOffset - The offset (in bytes) into the input array where the BGRA pixel starts
 * @returns {Uint8Array} - A new Uint8Array containing the single RGB triplet
 */
function RGBfromBGRAarray(array, arrayOffset) {
    return new Uint8Array([
        array[arrayOffset + 2], // R
        array[arrayOffset + 1], // G
        array[arrayOffset]      // B
    ]);
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

MAIN.readTransforms = (id2transformOutput) => {
    // Wipe all transforms
    [...Array(72).keys()].map((i) => id2transformOutput[i] = [])

    faceId2TfIndex = {}
    // read index
    for (const index of [...Array(72).keys()]) {
        const offset = getByteOffset_index(index)
        const data = imageData[offset]
        if (data == 0xff) {
            continue // FIXME 0 is valid?
        }
        faceId2TfIndex[index] = data
        console.log(`readTransforms> I[${index}] = ${data}`, data)
    }

    for (let [faceindex, tfIndex] of Object.entries(faceId2TfIndex)) {
        id2transformOutput[faceindex] = []

        let sortno = 1 // number used for list sorting
        while (tfIndex != 255) {
            // HEADER
            const headerOffset = getByteOffset_transform(tfIndex)
            const headerBuf = RGBfromBGRAarray(imageData, headerOffset)

            const header = MAIN.transformHeaderParser.parse(headerBuf)
            const T_next = header["T_next"]
            const T_size = header["T_size"]
            const T_type = header["T_type"]
            console.log("header=", headerBuf, header, imageData[getByteOffset(0,0,0)].toString(16))

            // DATA
            const dataOffset = getByteOffset_transform(tfIndex+1)
            const dataBuf = RGBfromBGRAarray(imageData, dataOffset)

            const data = MAIN.transform_parsers[T_type].parse(dataBuf)

            // Add to GUI
            console.log(`readTransforms> parse[${faceindex}]:`, data)
            id2transformOutput[faceindex].push({
                "face":`${faceindex}`,
                "id":sortno,
                "type":T_type,
                "data":data
            })

            sortno++;
            tfIndex = T_next;
        }
    }
}
MAIN.writeTransformsAndRender = (id2transform) => {
    console.log("MAIN.writeTransformsAndRender")

    const serializedTransforms = new Uint32Array(96).fill(0xFFFFFFFF);
    const serializedIndexs = new Uint8Array(72).fill(0xFF);
    let maxIndex = 0

    // fill serializedIndexs, serializedTransforms
    for ([faceId, faceTransfroms] of Object.entries(id2transform)){
        if (faceTransfroms.length === 0) {
            continue
        }

        // next of last entry is always 255
        let nextIndex = 255

        for (let tfJson of [...faceTransfroms].reverse()) {
            const T_type = tfJson.type

            // Create Header
            const header = MAIN.transformHeaderParser.encode({
                "T_next": nextIndex,
                "T_size": 1,
                "T_type": T_type,
            })
            nextIndex = maxIndex; // remember my index for next iteration

            // Create Data
            const data = MAIN.transform_parsers[T_type].encode(tfJson["data"]);

            // Serialize
            serializedTransforms[maxIndex] = serialize3BytesToRGBA(header)
            maxIndex++;
            serializedTransforms[maxIndex] = serialize3BytesToRGBA(data)
            maxIndex++;

            logHexAndBin(data, tfJson);
        }

        // First facetransform should be used in lookup.
        serializedIndexs[faceId] = nextIndex
        console.log(`${nextIndex} = serializedFaceEntries[${faceId}]`);
    }

    // pixel write indexes
    for (let [index, int] of serializedIndexs.entries()) {
        const offset = getByteOffset_index(index)
        imageData[offset] = int

        if(int != 0xFF) {
            console.log(`F pos=${index} offset=${offset}, value=0x${int.toString(16)}`)
        }
    }

    // pixel write transforms
    for (let [index, int] of serializedTransforms.entries()) {
        const offset = getByteOffset_transform(index)
        imageData[offset+0] = (int >> 24) & 0xff
        imageData[offset+1] = (int >> 16) & 0xff
        imageData[offset+2] = (int >> 8) & 0xff
        imageData[offset+3] = (int >> 0) & 0xff

        if(int != 0xFFFFFFFF) {
            const hexstr = [...Array(4).keys()].map(
                (x) => imageData[offset+x].toString(16).padStart(2, "0")
            ).join("|")
            console.log(`T pos=${index} offset=${offset}, value=${hexstr}`)
        }
    }

    // Enable
    imageData[getByteOffset(0,0,0)] = 0xda
    imageData[getByteOffset(0,0,1)] = 0x67

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

MAIN.transformHeaderParser = (
    new BinaryParser.Parser()
        .endianess("little")
        .encoderSetOptions({bitEndianess: true})
        .bit8("T_next")
        .bit8("T_size")
        .bit8("T_type")
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
    0: [[8, 0], [16, 8]],
    1: [[16, 0], [24, 8]],
    2: [[0, 8], [8, 16]],
    3: [[8, 8], [16, 16]],
    4: [[16, 8], [24, 16]],
    5: [[24, 8], [32, 16]],
    6: [[20, 16], [28, 20]],
    7: [[28, 16], [36, 20]],
    8: [[16, 20], [20, 32]],
    9: [[20, 20], [28, 32]],
    10: [[28, 20], [32, 32]],
    11: [[32, 20], [40, 32]],
    12: [[44, 16], [48, 20]],
    13: [[48, 16], [52, 20]],
    14: [[40, 20], [44, 32]],
    15: [[44, 20], [48, 32]],
    16: [[48, 20], [52, 32]],
    17: [[52, 20], [56, 32]],
    18: [[40, 48], [44, 52]],
    19: [[44, 48], [48, 52]],
    20: [[32, 52], [36, 64]],
    21: [[36, 52], [40, 64]],
    22: [[40, 52], [44, 64]],
    23: [[44, 52], [48, 64]],
    24: [[4, 16], [8, 20]],
    25: [[8, 16], [12, 20]],
    26: [[0, 20], [4, 32]],
    27: [[4, 20], [8, 32]],
    28: [[8, 20], [12, 32]],
    29: [[12, 20], [16, 32]],
    30: [[20, 48], [24, 52]],
    31: [[24, 48], [28, 52]],
    32: [[16, 52], [20, 64]],
    33: [[20, 52], [24, 64]],
    34: [[24, 52], [28, 64]],
    35: [[28, 52], [32, 64]],
    36: [[40, 0], [48, 8]],
    37: [[48, 0], [56, 8]],
    38: [[32, 8], [40, 16]],
    39: [[40, 8], [48, 16]],
    40: [[48, 8], [56, 16]],
    41: [[56, 8], [64, 16]],
    42: [[4, 48], [8, 52]],
    43: [[8, 48], [12, 52]],
    44: [[0, 52], [4, 64]],
    45: [[4, 52], [8, 64]],
    46: [[8, 52], [12, 64]],
    47: [[12, 52], [16, 64]],
    48: [[4, 32], [8, 36]],
    49: [[8, 32], [12, 36]],
    50: [[0, 36], [4, 48]],
    51: [[4, 36], [8, 48]],
    52: [[8, 36], [12, 48]],
    53: [[12, 36], [16, 48]],
    54: [[52, 48], [56, 52]],
    55: [[56, 48], [60, 52]],
    56: [[48, 52], [52, 64]],
    57: [[52, 52], [56, 64]],
    58: [[56, 52], [60, 64]],
    59: [[60, 52], [64, 64]],
    60: [[44, 16], [48, 20]],
    61: [[48, 16], [52, 20]],
    62: [[40, 20], [44, 32]],
    63: [[44, 20], [48, 32]],
    64: [[48, 20], [52, 32]],
    65: [[52, 20], [56, 32]],
    66: [[20, 32], [28, 36]],
    67: [[28, 32], [36, 36]],
    68: [[16, 36], [20, 48]],
    69: [[20, 36], [28, 48]],
    70: [[28, 36], [32, 48]],
    71: [[32, 36], [40, 48]],
}