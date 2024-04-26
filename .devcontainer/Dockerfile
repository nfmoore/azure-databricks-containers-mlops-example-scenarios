FROM mcr.microsoft.com/devcontainers/python:1-3.10-bullseye

# # Install Databricks CLI
RUN  curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sudo sh

# Copy Python dependencies
COPY ./requirements.txt ./requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r ./requirements.txt

# Install Azure ClI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash && az bicep install

# Connect as root non-root user. More info: https://aka.ms/dev-containers-non-root.
USER vscode

# Add zsh-autosuggestions 
RUN git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
RUN printf 'source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh\n' >> ~/.zshrc

# Add zsh-syntax-highlighting
RUN git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting
RUN printf 'source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh\n' >> ~/.zshrc
