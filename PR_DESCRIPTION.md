# feat(docs): tutorial for streaming local files into a Ray cluster on Kubernetes

Closes #684

## Feature request

Users want to train models on datasets that live on their local laptop/workstation while the Ray cluster runs inside a Kubernetes cluster (e.g., deployed via KubeRay). The naive approach fails:

```python
import ray

class LocalFile:
    def read(self, path):
        with open(path, "rb") as f:
            return f.read()

@ray.remote
def train(fo):
    print(fo.read("../../temp-ds"))

if __name__ == "__main__":
    ray.init(address="ray://localhost:10001")
    file = LocalFile()
    file_ref = ray.put(file)
    ray.get(train.remote(file_ref))
```

The remote task executes on a worker pod and `../../temp-ds` resolves to a path inside the pod, not the local machine. The object reference (`ray.put(file)`) only serializes the object; the file contents on the local disk are not transferred automatically.

## Proposed solution

Add a tutorial that shows the officially supported ways to get local data into a Kubernetes-backed Ray cluster, ordered from simplest to most robust.

### 1. `runtime_env` with `working_dir` (recommended for code + small data)

Package the local directory (Python modules + data) and let Ray upload it to the cluster when the job is submitted.

```python
ray.init(
    address="ray://localhost:10001",
    runtime_env={"working_dir": "/path/to/local/project"},
)
```

Inside the remote task, read files relative to the working directory. This works for datasets up to a few hundred MBs and is the best option for development.

### 2. `ray.data.read_*` for large datasets

For larger datasets, use Ray Data to load local files in parallel, convert them to Ray's distributed object format, and pass references to the training task.

```python
import ray

ray.init(address="ray://localhost:10001")

ds = ray.data.read_parquet("/local/path/to/dataset")
# The dataset is partitioned and streamed to the cluster as needed.

train_actor = Train.remote()
ray.get(train_actor.fit.remote(ds))
```

Caveat: local filesystem readers still need the data to be accessible. For a cluster on Kubernetes, use one of the persistent-storage options below for datasets that do not fit in `working_dir`.

### 3. Shared persistent volume (PVC) attached to the Ray cluster

Create a Kubernetes PVC and mount it into the head/worker pods via KubeRay's `volumes` / `volumeMounts` fields. The user copies data once with `kubectl cp` or a Kubernetes data-loader Job, and all Ray workers can read it.

```yaml
# KubeRayCluster snippet
worker:
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: ray-data-pvc
  volumeMounts:
    - name: data
      mountPath: /mnt/data
```

```python
@ray.remote
def train():
    ds = ray.data.read_parquet("/mnt/data/dataset")
    ...
```

This is the best option for large, reusable datasets and for production.

### 4. Object-store / cloud-storage staging (S3, GCS, MinIO, etc.)

For datasets that are too large or too sensitive for `working_dir`, upload to object storage and read from the cluster. KubeRay clusters can be configured with IAM roles or credentials (e.g., Kubernetes service-account + IRSA for S3, or GKE workload identity for GCS).

```python
@ray.remote
def train():
    ds = ray.data.read_parquet("s3://my-bucket/dataset/")
    ...
```

## Tutorial outline

The tutorial will cover:

1. Why `ray.put(LocalFile())` does not stream local files automatically.
2. Choosing between the four options above.
3. A complete end-to-end example using `working_dir` + a small CSV.
4. A complete example using a PVC mounted in the KubeRay cluster.
5. Troubleshooting checklist (paths, PVC permissions, `runtime_env` size limits, network timeouts).

## Acceptance criteria

- A new markdown tutorial under `docs/` or `ray-operator/config/samples/` explaining the recommended patterns.
- Working code snippets for `working_dir`, PVC, and object-storage approaches.
- Clear guidance on which approach to choose based on dataset size and cluster lifecycle.
- The tutorial directly answers the scenario described in #684.

## Verification

1. Follow the PVC tutorial to create a KubeRay cluster with a mounted PVC.
2. Copy a local CSV into the PVC with `kubectl cp`.
3. Run the example remote task and confirm it reads the file from `/mnt/data`.
4. Follow the `working_dir` tutorial and confirm the dataset is uploaded and accessible to remote tasks.

## References

- Ray `runtime_env` docs: https://docs.ray.io/en/latest/ray-core/handling-dependencies.html
- Ray Data docs: https://docs.ray.io/en/latest/data/data.html
- KubeRay volumes docs: https://ray-project.github.io/kuberay/guidance/volumes/
