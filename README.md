# Dev Container

This setup provides a consistent, isolated development environment. It is useful for normal development and for sandboxing coding agents away from host credentials and services.

Copy `.devcontainer`, `env.example`, and `mise.toml` to the repository root. Rename `env.example` to `dev.env` and update its values.

The example [`mise.toml`](https://mise.jdx.dev/) manages project development tools, including agent CLIs. Adjust its tools and versions for your project.

Install the Dev Container CLI on the host with mise:

```sh
mise use -g devcontainer-cli@latest
```

Create and start the container, then run commands inside it:

```sh
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . <command>
```
