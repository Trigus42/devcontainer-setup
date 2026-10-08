FROM mcr.microsoft.com/devcontainers/base:trixie

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        starship \
        zsh-autosuggestions \
        zsh-syntax-highlighting \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

COPY .zshrc /home/vscode/.zshrc
COPY .zshrc /root/.zshrc
COPY starship.toml /home/vscode/.config/starship.toml
RUN chown -R vscode:vscode /home/vscode/.zshrc /home/vscode/.config/starship.toml \
    && chsh -s /bin/zsh vscode
ENV SHELL=/bin/zsh
