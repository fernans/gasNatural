# gasNatural (AIR / Away3D / Kinect)

> **This project is shared ONLY for educational purposes. Its use, direct or derived, for professional or economic purposes is not permitted.**

An interactive ActionScript 3 / Adobe AIR photo-installation prototype: a Kinect skeleton drives an avatar wearing virtual garments (pyjamas, robe, apron) over pre-recorded room backgrounds, with calibration keys and JPEG photo capture. The repository keeps the main source (`dev/Main.as`), test harness (`test/Main.as`), reference sources (`refs/`), 3ds Max material and the packaged AIR builds.

For security reasons, some parts of the project may have been edited or removed. Third-party copyright headers, contact addresses, URLs and reference paths in `refs/` were deliberately preserved; no source code was modified.

## Requirements / How to run

- ActionScript 3; Adobe Flash Professional compatible with the authoring file `dev/probador.fla` (CWS/FLA, ~129 MB) and Adobe AIR 13 runtime (see `dev/probador-app.xml` and `test/test-app.xml`).
- Away3D (FP11 examples and AWD assets under `refs/away/`) and the `as3nui` AIRKinect 2 ANE (`airkinect-2-core-mssdk.ane`); Windows only.
- Microsoft Kinect SDK v1.6 and Kinect Developer Toolkit v1.6.0 (`redist/` installers, excluded from this repository by size).
- Optional remote control: MCE Controller listening on `localhost:5150` (commands documented in `release/how.txt`).
- Open `dev/probador.fla`, publish `probador.swf`, then package/run it with the AIR descriptor; `dev/probador.exe` and `dev/probador.app/` are historical packaged builds. Calibration shortcuts are listed in `dev/teclas.txt`.
- No warranty is provided; the software is supplied "as is" and no liability is accepted for errors or damages arising from its use.

## Large assets

Download `gasNatural-assets.zip` from the **Releases** tab and extract it into the project root, preserving the folder structure. It contains the six files over 100 MB that cannot be stored in this repository:

- `material/graficos/fondos_videos/DORMITORIO.mov`, `DUCHA.mov`, `COCINA.mov`
- `dev/probador.fla`
- `redist/KinectSDK-v1.6-Setup.exe`, `redist/KinectDeveloperToolkit-v1.6.0-Setup.exe`

Multimedia and binaries smaller than 100 MB remain in the repository.

## Excluded material

AIR package signature XML files containing X.509 certificates (`dev/probador.app/META-INF/signatures.xml`, `test/test.app/META-INF/signatures.xml`) and the packaged-app RARs that embed them (`dev/probador.app.rar`, `test/test.app.rar`) are not published. No private keys, keygens, cracks, serials or evident passwords were found. The obsolete backup folder `dev/_bak/` and the old ANE copy are ignored but kept locally. Third-party `refs/` libraries and SDKs are retained in full.

> **AI training**: the use of the content of this repository (code, assets, documentation) to train or fine-tune machine learning models or AI systems is expressly **not permitted**. All of the repository is licensed under CC-BY-NC-4.0 (see the `LICENSE` file).

---

# gasNatural (AIR / Away3D / Kinect)

> **Este proyecto se comparte SOLO con valor educativo. No está permitido su uso (directo o derivado) para fines profesionales o económicos.**

Prototipo interactivo en ActionScript 3 / Adobe AIR para una instalación fotográfica: el esqueleto detectado por Kinect controla un avatar con prendas virtuales (pijama, albornoz, delantal) sobre fondos de habitación grabados, con teclas de calibración y captura de fotos en JPEG. Se conservan el fuente principal (`dev/Main.as`), el banco de pruebas (`test/Main.as`), los fuentes de referencia (`refs/`), los materiales de 3ds Max y las compilaciones AIR empaquetadas.

Por motivos de seguridad, es posible que algunas partes se encuentren editadas o eliminadas. Las cabeceras de copyright, direcciones de contacto, URLs y rutas de referencia de terceros en `refs/` se conservan deliberadamente; no se modificó el código fuente.

## Requisitos / Cómo ejecutar

- ActionScript 3; Adobe Flash Professional compatible con el archivo de autoría `dev/probador.fla` (CWS/FLA, ~129 MB) y Adobe AIR 13 (ver `dev/probador-app.xml` y `test/test-app.xml`).
- Away3D (ejemplos FP11 y recursos AWD en `refs/away/`) y el ANE `as3nui` AIRKinect 2 (`airkinect-2-core-mssdk.ane`); solo Windows.
- Microsoft Kinect SDK v1.6 y Kinect Developer Toolkit v1.6.0 (instaladores en `redist/`, excluidos de este repositorio por tamaño).
- Control remoto opcional: MCE Controller escuchando en `localhost:5150` (comandos documentados en `release/how.txt`).
- Abrir `dev/probador.fla`, publicar `probador.swf` y empaquetarlo/ejecutarlo con el descriptor AIR; `dev/probador.exe` y `dev/probador.app/` son compilaciones históricas. Los atajos de calibración están en `dev/teclas.txt`.
- El software se proporciona «tal cual», sin ningún tipo de garantía. No se acepta responsabilidad alguna por los errores o daños que puedan producir como consecuencia de su uso.

## Archivos grandes

Descarga `gasNatural-assets.zip` desde la pestaña **Releases** y extráelo en la raíz del proyecto, manteniendo la estructura de carpetas. Contiene los seis archivos de más de 100 MB que no pueden incluirse en este repositorio:

- `material/graficos/fondos_videos/DORMITORIO.mov`, `DUCHA.mov`, `COCINA.mov`
- `dev/probador.fla`
- `redist/KinectSDK-v1.6-Setup.exe`, `redist/KinectDeveloperToolkit-v1.6.0-Setup.exe`

Los recursos multimedia y binarios de menos de 100 MB permanecen en el repositorio.

## Material excluido

No se publican los XML de firma de paquetes AIR que contienen certificados X.509 (`dev/probador.app/META-INF/signatures.xml`, `test/test.app/META-INF/signatures.xml`) ni los RAR de las aplicaciones empaquetadas que los incluyen (`dev/probador.app.rar`, `test/test.app.rar`). No se encontraron llaves privadas, keygens, cracks, seriales ni contraseñas evidentes. La carpeta obsoleta de copias de seguridad `dev/_bak/` y la copia antigua del ANE se ignoran, pero se conservan localmente. Las librerías y SDK de terceros en `refs/` se conservan íntegramente.

> **Entrenamiento de IA**: no se permite expresamente el uso del contenido de este repositorio (código, recursos, documentación) para entrenar o ajustar (*fine-tune*) modelos de aprendizaje automático o sistemas de IA. Todo el repositorio se publica con licencia CC-BY-NC-4.0 (ver el archivo `LICENSE`).
