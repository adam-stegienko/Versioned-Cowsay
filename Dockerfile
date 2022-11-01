FROM node:16.17
RUN mkdir /app
WORKDIR /app
COPY ./src ./

RUN npm install

RUN echo "#!/bin/bash \n npm start" > ./entry-point.sh
RUN chmod +x ./entry-point.sh
ENTRYPOINT ./entry-point.sh