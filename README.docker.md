# Running stanford-stages with Docker

This is a guide to running the sleep stage classifier in a container. Docker
bundles Python 3.7 and the full scientific stack (TensorFlow 2.5, GPflow, etc.)
into an image, so you do not need to set up conda or install dependencies by
hand. You only need to supply the models and an EDF recording.

## One-time setup

1. Fetch the LSTM models (~770 MiB into `ml/ac/`) and, optionally, a sample
   `CHP040.edf` recording into `data/input/`:

   ```sh
   ./get_assets.sh            # models + sample EDF
   ./get_assets.sh models     # models only
   ```

2. Put one or more `.edf` files under `data/input/`.

3. Edit `stanford_stages.docker.json` so it matches your recording - in
   particular the `edf_filename` and `channel_labels` entries.

## Run

From the repository root:

```sh
docker compose up --build
```

Results (hypnogram, hypnodensity, encoding, plot) are written to
`data/output/`. The first build downloads TensorFlow and friends and takes
several minutes; later runs reuse the cached image.

## Common overrides

- **Use a different config:** set `CONFIG=/app/my_config.json` in the
  environment before `docker compose up`, or pass the config path to a plain
  `docker run ... /app/my_config.json`.
- **Process every `.edf` in a folder:** change `edf_filename` to `edf_pathname`
  pointing at `/data/input` in the config
  (see `documentation/JSON_Configuration.md`).
- **Open a shell in the image:**
  `docker compose run --rm stanford-stages bash`.
- **Use an Nvidia GPU:** add a `deploy.resources.reservations.devices` block
  targeting the GPU and switch to a `tensorflow:2.5.0-gpu` base image. The
  default image is CPU-only and runs anywhere.

## Where things live

| Path (in container) | What it is |
| --- | --- |
| `/data/input` | mount point for your `.edf` recordings (read-only) |
| `/data/output` | mount point for results, written by the container |
| `/app/ml/ac` | the large LSTM models, mounted from `ml/ac/` at runtime |
| `/app/stanford_stages.docker.json` | the config the container runs by default |

The smaller ML assets (`ml/scaling/`, `ml/noiseM.mat`) are already in the repo
and are baked into the image; only the large `ml/ac` models are mounted.

Note: `show.plot` is `false` in the bundled config because the container has no
display. Plots are still written to disk via `save.plot: true`.

## Rebuilding

```sh
docker compose up --build              # rebuild and run
docker build --no-cache -t stanford-stages:latest .   # clean dependency rebuild
```

The dependency layer is cached, so a rebuild after a source-only change is
fast.

---

# Dependency fixes (pip vs conda)

The repo's root `requirements.txt` is the maintainers' canonical spec, but it
is written for a conda workflow and is not satisfiable under pip. The Docker
image installs from `docker/requirements.txt` and `docker/constraints.txt`
instead, leaving the original file untouched. The differences and why they are
needed:

## 1. Two entries are not valid package specs

- `pyEDFlib.egg==info` - not a real PyPI package. Removed.
- `skimage==0.0` - wrong package name; `skimage` is the import name provided by
  `scikit_image`, which is already pinned. Removed.

## 2. pyedflib 0.1.22 fails to build with Cython 3.x

`pyedflib==0.1.22` has no wheel for Python 3.7, so pip builds it from source,
and its `.pyx` file crashes the Cython 3.x compiler. `constraints.txt` pins
`Cython<3.0`; the `PIP_CONSTRAINT` env var in the Dockerfile propagates this
into pip's build-isolation environment so the wheel builds against Cython
0.29.x.

## 3. h5py pin conflicts with TensorFlow

The root file pins `h5py==2.10.0` alongside `tensorflow==2.5.0`, but
`tensorflow 2.5.0` requires `h5py~=3.1.0`. This only resolves in the conda flow
because of install ordering. The Docker requirements pin the pip-satisfiable
`h5py==3.1.0`.

This is safe here: the app's h5py usage is limited to opening files, dataset
assignment, and reading with `[()]` (see `inf_hypnodensity.py`), none of which
changed between h5py 2.x and 3.x. The 2-to-3 breaking change was string
decoding, and the only string dataset written (`channels_used`) uses
`dtype='S'` and is never decoded as text.

## 4. tensorflow-probability must be pinned

GPflow 2.1.4 declares `tensorflow-probability>=0.11` with no upper bound, so
pip pulls the latest, which requires `tensorflow>=2.11` and fails to import
against TensorFlow 2.5.0. `tensorflow-probability==0.13.0` is compatible with
both and is pinned explicitly.

## 5. tf_nightly_2.0_preview dropped

The root file lists `tf_nightly_2.0_preview==2.0.0.dev20191002`, which
conflicts with `tensorflow==2.5.0` and is not needed (tensorflow installs the
equivalent as a dependency). It is omitted.
