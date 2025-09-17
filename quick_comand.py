import subprocess
import requests
import os
from datetime import datetime

# Configurações
PIPELINE_COMMAND = "gh workflow run DevTest-with-Lys-Agent"  # Comando para rodar a pipeline
LOG_FILE = "pipeline.log"  # Arquivo de log gerado pela pipeline
REPO_PATH = "/caminho/para/seu/repo"  # Caminho para o repositório
LYS_API_URL = "https://genai-inference-app.stackspot.com/v1/agent/765240/chat"  # URL da API da Lys
STACKSPOT_AUTH_URL = "https://idm.stackspot.com/{REALM}/oidc/oauth/token"  # URL de autenticação
CLIENT_ID = "secrets.CLIENT_ID"  # Substitua pelo seu Client ID
CLIENT_SECRET = "secrets.CLIENT_KEY"  # Substitua pelo seu Client Secret

def run_pipeline():
    """Executa a pipeline e captura os logs."""
    print("Executando a pipeline...")
    process = subprocess.run(PIPELINE_COMMAND, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    with open(LOG_FILE, "w") as log:
        log.write(process.stdout.decode())
        log.write(process.stderr.decode())
    return process.returncode

def check_for_errors(log_file):
    """Verifica se há erros no log."""
    with open(log_file, "r") as log:
        logs = log.read()
        if "error_log=" in logs:
            # Extrai o log de erro do arquivo
            start = logs.find("error_log=") + len("error_log=")
            end = logs.find("\n", start)
            return logs[start:end]
    return None

def authenticate_with_stackspot():
    """Autentica com o StackSpot e retorna o JWT."""
    print("Autenticando com o StackSpot...")
    payload = {
        "grant_type": "client_credentials",
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET
    }
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    response = requests.post(STACKSPOT_AUTH_URL, data=payload, headers=headers)
    if response.status_code == 200:
        return response.json().get("access_token")
    else:
        raise Exception(f"Falha na autenticação: {response.status_code} - {response.text}")

def query_lys(jwt, error_log):
    """Consulta a agente Lys com os logs de erro."""
    print("Consultando a agente Lys...")
    payload = {
        "streaming": False,
        "user_prompt": error_log,
        "stackspot_knowledge": False,
        "return_ks_in_response": True
    }
    headers = {
        "Authorization": f"Bearer {jwt}",
        "Content-Type": "application/json"
    }
    response = requests.post(LYS_API_URL, json=payload, headers=headers)
    if response.status_code == 200:
        return response.json()
    else:
        raise Exception(f"Erro ao consultar a Lys: {response.status_code} - {response.text}")

def log_response_to_repo(response):
    """Registra a resposta da Lys no repositório."""
    print("Registrando a resposta da Lys no repositório...")
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"\n[{timestamp}] Resposta da Lys:\n{response}\n"
    log_file_path = os.path.join(REPO_PATH, "lys_responses.log")
    with open(log_file_path, "a") as log_file:
        log_file.write(log_entry)
    # Comitar a alteração no repositório
    subprocess.run(f"git -C {REPO_PATH} add lys_responses.log", shell=True)
    subprocess.run(f'git -C {REPO_PATH} commit -m "Registro de resposta da Lys em {timestamp}"', shell=True)
    subprocess.run(f"git -C {REPO_PATH} push", shell=True)

def main():
    # Passo 1: Executa a pipeline
    return_code = run_pipeline()

    # Passo 2: Verifica se houve erro
    if return_code != 0:
        print("Erro detectado na pipeline. Verificando logs...")
        error_log = check_for_errors(LOG_FILE)
        if error_log:
            # Passo 3: Autentica com o StackSpot
            jwt = authenticate_with_stackspot()
            # Passo 4: Consulta a Lys
            response = query_lys(jwt, error_log)
            # Passo 5: Registra a resposta no repositório
            log_response_to_repo(response)
        else:
            print("Nenhum log de erro encontrado.")
    else:
        print("Pipeline executada com sucesso!")

if __name__ == "__main__":
    main()