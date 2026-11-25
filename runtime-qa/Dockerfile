FROM mcr.microsoft.com/playwright:v1.51.1-noble
WORKDIR /opt/arena
RUN npm install --no-save --no-package-lock playwright@1.51.1
COPY runner.mjs /opt/arena/runner.mjs
USER pwuser
ENTRYPOINT ["node","/opt/arena/runner.mjs"]
