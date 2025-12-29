package main

import (
	"os"

	"git.gay/besties/ios-safari-remote-debug/build"
	"git.gay/besties/ios-safari-remote-debug/server"
	"github.com/rs/zerolog/log"
	"github.com/urfave/cli/v2"
)

func main() {
	app := &cli.App{
		Description: "A tool for remotely debugging iOS Safari",
		Commands: []*cli.Command{
			{
				Name:  "build",
				Usage: "build the iOS Safari remote debugging tool",
				Flags: []cli.Flag{
					&cli.PathFlag{
						Name:    "output",
						Aliases: []string{"o"},
						Value:   "dist",
						Usage:   "output built iOS Safari debugger to `DIR`",
					},
					&cli.StringFlag{
						Name:    "tag",
						Aliases: []string{"t"},
						Value:   "main",
						Usage:   "the tag to clone from the WebKit repository",
					},
				},
				Action: func(ctx *cli.Context) error {
					tag := ctx.String("tag")
					clonePath, err := build.Clone(tag)
					if err != nil {
						return err
					}
					return build.Build(clonePath, ctx.Path("output"))
				},
			},
			{
				Name:  "serve",
				Usage: "serve the iOS Safari remote debugging tool once it's built",
				Flags: []cli.Flag{
					&cli.PathFlag{
						Name:    "input",
						Value:   "dist",
						Aliases: []string{"i"},
						Usage:   "serve built iOS Safari debugger from `DIR`",
					},
					&cli.StringFlag{
						Name:  "address",
						Usage: "the address to listen on",
						Value: ":8924",
					},
					&cli.StringFlag{
						Name:  "proxy-host",
						Usage: "the host:port of ios_webkit_debug_proxy (default: 127.0.0.1:9221). Use this if proxy is running in WSL or on a remote machine",
						Value: "127.0.0.1:9221",
					},
				},
				Action: server.ListenCommand,
			},
		},
	}

	if err := app.Run(os.Args); err != nil {
		log.Fatal().Err(err).Send()
	}
}
