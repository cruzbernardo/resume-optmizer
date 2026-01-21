module Templates
  RESUME_HTML = <<~HTML
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>[SEU NOME] - [SEU TÍTULO]</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                font-size: 11pt;
                line-height: 1.4;
                color: #000;
                max-width: 800px;
                margin: 0 auto;
                padding: 20px;
            }
            h1 {
                font-size: 18pt;
                margin-bottom: 5px;
                text-align: center;
            }
            h2 {
                font-size: 12pt;
                border-bottom: 1px solid #000;
                padding-bottom: 3px;
                margin-top: 15px;
                margin-bottom: 10px;
                text-transform: uppercase;
            }
            h3 {
                font-size: 11pt;
                margin-bottom: 2px;
            }
            .header {
                text-align: center;
                margin-bottom: 15px;
            }
            .subtitle {
                font-size: 11pt;
                margin-bottom: 8px;
            }
            .contact {
                font-size: 10pt;
            }
            .job-header {
                display: flex;
                justify-content: space-between;
                margin-bottom: 3px;
            }
            .company {
                font-weight: bold;
            }
            .position {
                font-style: italic;
            }
            .period {
                text-align: right;
            }
            ul {
                margin: 5px 0 15px 20px;
                padding: 0;
            }
            li {
                margin-bottom: 4px;
            }
            p {
                margin: 0 0 10px 0;
                text-align: justify;
            }
            .skills-list {
                margin: 0;
            }
            .education-item {
                margin-bottom: 8px;
            }
            @media print {
                body {
                    padding: 0;
                }
            }
        </style>
    </head>
    <body>

        <div class="header">
            <h1>[SEU NOME COMPLETO]</h1>
            <p class="subtitle">[TÍTULO] | [TECNOLOGIA 1] | [TECNOLOGIA 2] | [TECNOLOGIA 3]</p>
            <p class="contact">
                [CIDADE], [ESTADO], Brasil | [TELEFONE] | [EMAIL]<br>
                linkedin.com/in/[SEU-LINKEDIN] | github.com/[SEU-GITHUB]
            </p>
        </div>

        <h2>Resumo Profissional</h2>
        <p>
            [TÍTULO/CARGO] com [X] anos de experiência em [ÁREA PRINCIPAL].
            Experiência sólida em [TECNOLOGIA 1], [TECNOLOGIA 2] e [TECNOLOGIA 3].
            [DESCREVA O TIPO DE TRABALHO QUE VOCÊ FAZ].
            [MENCIONE PRÁTICAS/METODOLOGIAS].
            [SOFT SKILLS RELEVANTES].
        </p>

        <h2>Competências Técnicas</h2>
        <p class="skills-list">
            <strong>Linguagens:</strong> [Ex: Node.js, JavaScript, TypeScript, Python, SQL]<br>
            <strong>Frameworks:</strong> [Ex: NestJS, Express, Django, Ruby on Rails]<br>
            <strong>Banco de Dados:</strong> [Ex: PostgreSQL, MySQL, MongoDB, Redis]<br>
            <strong>Cloud:</strong> [Ex: AWS (Lambda, S3, EC2), GCP, Azure]<br>
            <strong>DevOps:</strong> [Ex: Docker, CI/CD, Git]<br>
            <strong>Práticas:</strong> [Ex: TDD, Clean Code, Design Patterns, SOLID]<br>
            <strong>Outras:</strong> [Ex: APIs REST, Microsserviços, Metodologias Ágeis]
        </p>

        <h2>Experiência Profissional</h2>

        <div class="job-header">
            <span class="company">[NOME DA EMPRESA]</span>
            <span class="period">[Mmm AAAA] - Presente</span>
        </div>
        <p class="position">[Seu Cargo]</p>
        <ul>
            <li>[Verbo de ação] + [O que você fez] + [Tecnologias usadas] + [Resultado/Impacto se houver].</li>
            <li>[Exemplo: "Desenvolvimento de APIs RESTful escaláveis utilizando Node.js e NestJS, com integração a sistemas externos."]</li>
            <li>[Exemplo: "Modelagem de dados em PostgreSQL e otimização de queries para alta performance."]</li>
            <li>[Exemplo: "Participação em reuniões técnicas com clientes, alinhando soluções técnicas com objetivos de negócio."]</li>
            <li>[Exemplo: "Aplicação de boas práticas: testes automatizados, code review, CI/CD e clean code."]</li>
        </ul>

        <div class="job-header">
            <span class="company">[NOME DA EMPRESA]</span>
            <span class="period">[Mmm AAAA] - [Mmm AAAA]</span>
        </div>
        <p class="position">[Seu Cargo]</p>
        <ul>
            <li>[Descreva suas responsabilidades e conquistas]</li>
            <li>[Use verbos de ação no passado: "Desenvolvi", "Implementei", "Refatorei"]</li>
            <li>[Seja específico sobre tecnologias e resultados]</li>
        </ul>

        <div class="job-header">
            <span class="company">[NOME DA EMPRESA]</span>
            <span class="period">[Mmm AAAA] - [Mmm AAAA]</span>
        </div>
        <p class="position">[Seu Cargo]</p>
        <ul>
            <li>[Descreva suas responsabilidades e conquistas]</li>
            <li>[Mantenha bullets concisos - máximo 2 linhas cada]</li>
        </ul>

        <h2>Formação Acadêmica</h2>

        <div class="education-item">
            <strong>[INSTITUIÇÃO]</strong> - [GRAU] em [CURSO] ([ANO INÍCIO] - [ANO FIM])<br>
            [Descrição opcional]
        </div>

        <div class="education-item">
            <strong>[INSTITUIÇÃO]</strong> - [GRAU] em [CURSO] ([ANO INÍCIO] - [ANO FIM])
        </div>

        <div class="education-item">
            <strong>[PLATAFORMA/INSTITUIÇÃO]</strong> - [NOME DO CURSO] ([PERÍODO])
        </div>

        <h2>Idiomas</h2>
        <p>Português: Nativo | Inglês: [NÍVEL] | [OUTRO IDIOMA]: [NÍVEL]</p>

        <h2>Competências Comportamentais</h2>
        <p>[Ex: Colaboração Eficaz, Comunicação Clara, Resolução de Problemas, Aprendizado Contínuo, Trabalho em Equipe, Autonomia, Foco em Resultados]</p>

    </body>
    </html>
  HTML
end
