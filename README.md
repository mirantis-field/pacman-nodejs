# pacman-nodejs

Pac-Man Node.js application - test

## Local Development

Using `docker-compose` you can start a local development environment. This environment will bind mount the applications
`src` directory into the container and then uses `nodemon` to detect changes and rebuild the application live.

### Linux

#### Start

Start the local development enviornment

```
cd pacman-nodejs
bin/linux/development-compose-up.sh
```

#### Stop

Stop the local development enviornment

```
cd pacman-nodejs
bin/linux/development-compose-up.sh
```

## Local Production

Using `docker-compose` you can start a local production environment. This environment will bind mount the applications
`src` directory into the container but will **NOT** detect changes and rebuild the application live.

### Linux

#### Start

Start the local production enviornment

```
cd pacman-nodejs
bin/linux/production-compose-up.sh
```

#### Stop

Stop the local production enviornment

```
cd pacman-nodejs
bin/linux/production-compose-up.sh
```

## Production

This application can be deployed on Kubernetes or Swarm using the YAML files in thier respective directories
(`kubernetes/cluster/` or `swarm/`). The repository is currently setup to use the Mirantis Docker Enterprise
Demo environments. This includes a Jenkins server and all of the automation to deploy the application onto
the selected cluster.

### How to Deploy

```
git clone https://github.com/mirantis-field/pacman-nodejs.git
git checkout -b <mirantis.local username>
git push --set-upstream origin <mirantis.local username>
```

The new branch will automatically be detected by Jenkins and deployed onto the default cluster using the default
orchestrator, specified in the `Jenkinsfile`.

### Changing the Deployment Cluster

To switch the deployment cluster, you can set the value of `TARGET_CLUSTER_DOMAIN` in the `Jenkinsfile`.
For available options check the Presales Docker Enterprise Environment wiki.

### Changing the Orchestrator

To switch between Kubernetes and Swarm, you can set the value of `ORCHESTRATOR` in the `Jenkinsfile`.
Available options are `"kubernetes"` or `"swarm"`

### Changing the Kubernetes Ingress

To switch between Kubernetes and Swarm, you can set the value of `KUBERNETES_INGRESS` in the `Jenkinsfile`.
Available options are `"ingress"` or `"istio_gateway"`
