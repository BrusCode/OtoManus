_otomanus.md", text = "# Guia de Contribuição para o OtoManus

Ficamos felizes com seu interesse em contribuir para o OtoManus! Este guia irá ajudá-lo a começar.

## Como Contribuir

- **Reportando Bugs:** Se encontrar um bug, por favor, abra uma [issue](https://github.com/BrusCode/OtoManus/issues) detalhando o problema, como reproduzi-lo, e a versão do OtoManus que você está usando.

- **Sugerindo Melhorias:** Tem uma ideia para uma nova funcionalidade ou melhoria? Abra uma [issue](https://github.com/BrusCode/OtoManus/issues) para discutir sua ideia.

- **Pull Requests:** Pull requests são bem-vindos! Para grandes mudanças, por favor, abra uma issue primeiro para discutir o que você gostaria de mudar.

## Configuração do Ambiente de Desenvolvimento

1.  **Fork e Clone:**
    ```bash
    git clone https://github.com/SEU-USUARIO/OtoManus.git
    cd OtoManus
    ```

2.  **Crie uma branch:**
    ```bash
    git checkout -b sua-feature
    ```

3.  **Instale as dependências de desenvolvimento:**
    ```bash
    pip install -r requirements-dev.txt
    ```

4.  **Execute os testes:**
    ```bash
    pytest
    ```

## Estilo de Código

Usamos `black` para formatação de código e `flake8` para linting. Antes de commitar, por favor, execute:

```bash
black .
flake8 .
```

## Enviando um Pull Request

1.  Faça o commit de suas mudanças.
2.  Faça o push para sua branch.
3.  Abra um pull request para a branch `main` do repositório original.

Obrigado por sua contribuição!
