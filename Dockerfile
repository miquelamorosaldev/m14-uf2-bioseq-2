FROM nikolaik/python-nodejs:python3.12-nodejs20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies
COPY package.json package-lock.json ./
RUN npm ci

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED 1
RUN npm run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

COPY --from=builder /app/out ./out

## Flask

# TODO build on runner
RUN apk --no-cache add musl-dev linux-headers g++

COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt --no-cache-dir

RUN apk del musl-dev linux-headers g++

COPY api/ .

EXPOSE 80
CMD ["gunicorn", "--bind", "0.0.0.0:80", "app:app"]