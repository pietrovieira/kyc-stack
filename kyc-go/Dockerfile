FROM golang:1.27-alpine AS builder
WORKDIR /app
RUN apk add --no-cache git
COPY go.mod go.sum* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /api ./cmd/api
RUN CGO_ENABLED=0 go build -o /worker ./cmd/worker

FROM alpine:3.20
RUN apk add --no-cache ca-certificates curl
WORKDIR /app
COPY --from=builder /api /app/api
COPY --from=builder /worker /app/worker
EXPOSE 8080
# default to api, pode sobrescrever command para worker
CMD ["/app/api"]
