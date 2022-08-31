FROM golang:1.19 as build

WORKDIR /app

COPY go.mod .
COPY go.sum .

RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o authserv authserv.go

FROM gcr.io/distroless/base
COPY --from=build /app/authserv /

EXPOSE 50666

ENTRYPOINT ["/authserv"]
