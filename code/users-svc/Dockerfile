FROM node:11-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --production
COPY index.js ./
EXPOSE 3001
CMD ["npm", "start"]
