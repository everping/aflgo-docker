## Description
This project offers a Docker file for packing [aflgo](https://github.com/aflgo/aflgo) with libxml2

## Building
```shell
docker container build -t fuzzing
```

## Usage

```shell
docker run fuzzing <a_commit_id_of_libxml2>
```
