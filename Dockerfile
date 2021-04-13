ARG BASE_IMAGE=node:13.12.0-alpine3.10  

FROM ${BASE_IMAGE}

MAINTAINER Aaron Rueth <arueth@mirantis.com>

RUN mkdir -p  /home/node/app
WORKDIR  /home/node/app

COPY bin/docker-entrypoint.sh bin/wait-for /

COPY package.json ./
RUN npm install

COPY src /home/node/app/src

RUN npm install --production

EXPOSE 8080

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["npm", "start"]
