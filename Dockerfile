# syntax=docker/dockerfile:1.7

FROM node:16-bullseye-slim AS base
WORKDIR /app
ENV PNPM_HOME=/pnpm
ENV PATH=$PNPM_HOME:$PATH
ENV HUSKY=0
RUN apt-get update \
  && apt-get install -y --no-install-recommends openssl \
  && rm -rf /var/lib/apt/lists/* \
  && corepack enable \
  && corepack prepare pnpm@7.33.7 --activate

FROM base AS deps
COPY package.json pnpm-lock.yaml .npmrc ./
RUN --mount=type=cache,id=pnpm-store,target=/pnpm/store \
  pnpm install --frozen-lockfile

FROM base AS build
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN pnpm exec blitz codegen \
  && pnpm build \
  && node -e "const fs=require('fs'); const pkg=require('./package.json'); delete pkg.scripts.prepare; fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n')" \
  && pnpm prune --prod

FROM base AS runner
ENV NODE_ENV=production
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/.next ./.next
COPY --from=build /app/public ./public
COPY --from=build /app/app ./app
COPY --from=build /app/db ./db
COPY --from=build /app/mailers ./mailers
COPY --from=build /app/integrations ./integrations
COPY --from=build /app/blitz.config.ts ./blitz.config.ts
COPY --from=build /app/package.json ./package.json
COPY --from=build /app/.npmrc ./.npmrc
COPY --from=build /app/tsconfig.json ./tsconfig.json
COPY --from=build /app/types.ts ./types.ts
EXPOSE 3000
CMD ["pnpm", "start"]
