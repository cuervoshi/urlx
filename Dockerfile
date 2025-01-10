FROM node:18-alpine AS base

# Crear grupo y usuario nodejs con gid y uid 1001
RUN ["addgroup", "--system", "--gid", "1001", "nodejs"]
RUN ["adduser" , "--system", "--uid", "1001", "nodejs"]

# Ajustar permisos para que nodejs tenga acceso completo a /app
RUN mkdir -p /app && chown -R nodejs:nodejs /app && chmod -R u+rwX,g+rwX,o+rX /app


FROM base AS dependencies

# Instalar dependencias del sistema necesarias
RUN ["apk", "add", "--no-cache", "libc6-compat"]

# Configuración del directorio de trabajo
WORKDIR /app

# Copiar archivos necesarios para instalar dependencias
COPY package.json pnpm-lock.yaml ./

# Instalar pnpm globalmente e instalar dependencias de producción
RUN ["npm", "i", "-g", "pnpm"]
RUN ["pnpm", "i", "--frozen-lockfile", "--prod"]


FROM base AS build

WORKDIR /app

# Copiar dependencias desde la etapa de dependencies
COPY --from=dependencies /app/node_modules ./node_modules

# Copiar el resto del código fuente
COPY . .

# Instalar SWC y construir la aplicación
RUN ["npm", "i", "-g", "@swc/cli@^0.1.62"]
RUN ["npm", "run", "build"]


FROM base AS runner

WORKDIR /app

# Copiar la aplicación construida y las dependencias
COPY --from=build --chown=nodejs:nodejs /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules

# Ajustar permisos para garantizar acceso total en /app para nodejs
RUN chown -R nodejs:nodejs /app && chmod -R u+rwX,g+rwX,o+rX /app

# Configurar el usuario que ejecutará el contenedor
USER nodejs

# Variables de entorno
ENV NODE_ENV production
ENV PORT     3000

# Exponer el puerto de la aplicación
EXPOSE 3000

# Comando de entrada
ENTRYPOINT ["node", "dist/index.js"]
