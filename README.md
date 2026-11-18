# Build your first AI agent

A 25-minute hands-on lab. You'll see the difference between an LLM and an agent by running one yourself: you'll watch it choose tools, remember the conversation, ask for confirmation, and try to resist a hidden malicious instruction.

You don't need to install anything. All you need is a free GitHub account.

## Start

1. Sign in to GitHub.
2. Select the button below and then select **Create codespace**.

   [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/pmartino-msft-personal/ai-agent-lab?quickstart=1)

3. Wait 1–2 minutes while the environment sets up. The notebook `agent_lab.ipynb` opens automatically.
4. At the top right of the notebook, select **Select Kernel**, then **Python Environments**, then **Python 3.12**.
5. Run the first code cell. When asked, paste the class key that your lecturer shows you.
6. Run the cells from top to bottom and follow the instructions in the notebook.

For a step-by-step walkthrough of every part, open the [lab guide](docs/lab-guide.html).

## Rules

- Don't paste personal or confidential data into the agent.
- Don't share the class key. It stops working after the lesson.

## When you've finished

Your codespace stops by itself after 30 minutes of inactivity. To delete it, go to [github.com/codespaces](https://github.com/codespaces), select **...** next to it, then **Delete**.

## Learn more

- [Microsoft Agent Framework](https://github.com/microsoft/agent-framework)
- [Agent Framework documentation](https://learn.microsoft.com/agent-framework/)

## For the instructor

The `infra` folder deploys the model with Bicep: `infra/deploy.ps1` before the lesson, `infra/cleanup.ps1` straight after. See the instructor setup guide.
