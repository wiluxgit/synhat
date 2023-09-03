'use strict';

import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { OBJLoader } from 'three/addons/loaders/OBJLoader.js';

async function main() {
  const canvas = document.getElementById("canvasSkinPreview")
  const skinTexture = new THREE.CanvasTexture(canvas.getContext('2d').canvas);

  const renderCanvas = document.querySelector('#camera');
  const renderer = new THREE.WebGLRenderer({canvas: renderCanvas});

  const fov = 45;
  const aspect = 2;  // the canvas default
  const near = 0.1;
  const far = 100;
  const camera = new THREE.PerspectiveCamera(fov, aspect, near, far);
  camera.position.set(0, 10, 20);

  const controls = new OrbitControls(camera, renderCanvas);
  controls.target.set(0, 5, 0);
  controls.update();

  const scene = new THREE.Scene();
  scene.background = new THREE.Color('black');

  {
    const planeSize = 4000;

    const loader = new THREE.TextureLoader();
    const texture = loader.load('assets/checker.png');
    texture.wrapS = THREE.RepeatWrapping;
    texture.wrapT = THREE.RepeatWrapping;
    texture.minFilter = THREE.NearestFilter;
    texture.magFilter = THREE.NearestFilter;
    const repeats = planeSize / 200;
    texture.repeat.set(repeats, repeats);

    const planeGeo = new THREE.PlaneBufferGeometry(planeSize, planeSize);
    const planeMat = new THREE.MeshPhongMaterial({
      map: texture,
      side: THREE.DoubleSide,
    });
    const mesh = new THREE.Mesh(planeGeo, planeMat);
    mesh.rotation.x = Math.PI * -.5;
    //scene.add(mesh);
  }

  {
    const skyColor = 0xB1E1FF;  // light blue
    const groundColor = 0xB97A20;  // brownish orange
    const intensity = 1;
    const light = new THREE.HemisphereLight(skyColor, groundColor, intensity);
    scene.add(light);
  }

  {
    const color = 0xFFFFFF;
    const intensity = 1;
    const light = new THREE.DirectionalLight(color, intensity);
    light.position.set(5, 10, 2);
    scene.add(light);
    scene.add(light.target);
  }

  function frameArea(sizeToFitOnScreen, boxSize, boxCenter, camera) {
    const halfSizeToFitOnScreen = sizeToFitOnScreen * 0.5;
    const halfFovY = THREE.Math.degToRad(camera.fov * .5);
    const distance = halfSizeToFitOnScreen / Math.tan(halfFovY);
    // compute a unit vector that points in the direction the camera is now
    // in the xz plane from the center of the box
    const direction = (new THREE.Vector3())
      .subVectors(camera.position, boxCenter)
      .multiply(new THREE.Vector3(1, 0, 1))
      .normalize();

    // move the camera to a position distance units way from the center
    // in whatever direction the camera was from the center already
    camera.position.copy(direction.multiplyScalar(distance).add(boxCenter));

    // pick some near and far values for the frustum that
    // will contain the box.
    camera.near = boxSize / 100;
    camera.far = boxSize * 100;

    camera.updateProjectionMatrix();

    // point the camera to look at the center of the box
    camera.lookAt(boxCenter.x, boxCenter.y, boxCenter.z);
  }

  const forceTextureInitialization = function() {
    const material = new THREE.MeshBasicMaterial();
    const geometry = new THREE.PlaneBufferGeometry();
    const scene = new THREE.Scene();
    scene.add(new THREE.Mesh(geometry, material));
    const camera = new THREE.Camera();

    return function forceTextureInitialization(texture) {
      material.map = texture;
      renderer.render(scene, camera);
    };
  }();

  {
    //const textureLoader = new THREE.TextureLoader();
    const objLoader = new OBJLoader();

    objLoader.load( 'assets/steve.obj', (root) => {
      scene.add(root);

      root.traverse( async (child) => {
        if ( child.isMesh ) {
          const gl = renderer.getContext();
          const glTex = gl.createTexture();
          gl.bindTexture(gl.TEXTURE_2D, glTex);
          gl.texImage2D(
            gl.TEXTURE_2D, 0, gl.RGBA, 64, 64, 0,
            gl.RGBA, gl.UNSIGNED_BYTE,
            // TEMP
            canvas.getContext('2d').getImageData(0, 0, 64, 64).data
          )
          gl.generateMipmap(gl.TEXTURE_2D);
          gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

          // Hack to force in webgl texture in three
          // https://stackoverflow.com/questions/29325906/can-you-use-raw-webgl-textures-with-three-js
          const texture = new THREE.Texture();
          forceTextureInitialization(texture);
          const texProps = renderer.properties.get(texture);
          texProps.__webglTexture = glTex;

          const material = new THREE.ShaderMaterial({
            uniforms: {
              Sampler0: { type: "t", value: texture }
            },
            vertexShader: await fetch("shader/vertex.glsl", {credentials: 'same-origin'}).then((response) => response.text()),
            fragmentShader: await fetch("shader/fragment.glsl", {credentials: 'same-origin'}).then((response) => response.text()),
            glslVersion: THREE.GLSL3,
            side: THREE.DoubleSide,
          });

          /*
          skinTexture.wrapS = THREE.RepeatWrapping;
          skinTexture.wrapT = THREE.RepeatWrapping;
          skinTexture.minFilter = THREE.NearestFilter;
          skinTexture.magFilter = THREE.NearestFilter;
          skinTexture.flipY = false;
          skinTexture.needsUpdate = true;

          const material = new THREE.ShaderMaterial({
            uniforms: {
              Sampler0: { type: "t", value: skinTexture }
            },
            vertexShader: await fetch("shader/vertex.glsl", {credentials: 'same-origin'}).then((response) => response.text()),
            fragmentShader: await fetch("shader/fragment.glsl", {credentials: 'same-origin'}).then((response) => response.text()),
            glslVersion: THREE.GLSL3,
            side: THREE.DoubleSide,
          });
          */

          child.material = material;
          //child.material.map = texture;
          //child.material.transparent = true;
          //child.geometry.computeVertexNormals();
        }
      });

      scene.add(root);

      // CAMERA CONTROLS
      const box = new THREE.Box3().setFromObject(root);
      const boxSize = box.getSize(new THREE.Vector3()).length();
      const boxCenter = box.getCenter(new THREE.Vector3());

      // set the camera to frame the box
      frameArea(boxSize * 1.2, boxSize, boxCenter, camera);

      // update the Trackball controls to handle the new size
      controls.maxDistance = boxSize * 10;
      controls.target.copy(boxCenter);
      controls.update();
    });
  }

  function resizeRendererToDisplaySize(renderer) {
    const canvas = renderer.domElement;
    const width = canvas.clientWidth;
    const height = canvas.clientHeight;
    const needResize = canvas.width !== width || canvas.height !== height;
    if (needResize) {
      renderer.setSize(width, height, false);
    }
    return needResize;
  }

  function render() {
    if (resizeRendererToDisplaySize(renderer)) {
      const canvas = renderer.domElement;
      camera.aspect = canvas.clientWidth / canvas.clientHeight;
      camera.updateProjectionMatrix();
    }
    skinTexture.needsUpdate = true;
    renderer.render(scene, camera);
    requestAnimationFrame(render);
  }

  requestAnimationFrame(render);
}

main();
