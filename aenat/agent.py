import os
import urllib.request
from google.adk.agents.llm_agent import Agent
from google.adk import Workflow
from google.genai import types
from google.adk.events.event import Event

# Configure proxy settings from proxy_server or standard environment variables
proxy_server = os.getenv("proxy_server", os.getenv("HTTP_PROXY", "http://10.1.0.4:8888"))
if proxy_server:
    if not proxy_server.startswith("http://") and not proxy_server.startswith("https://"):
        proxy_url = f"http://{proxy_server}"
    else:
        proxy_url = proxy_server
    os.environ["HTTP_PROXY"] = proxy_url
    os.environ["HTTPS_PROXY"] = proxy_url
    os.environ["http_proxy"] = proxy_url
    os.environ["https_proxy"] = proxy_url

no_proxy_setting = os.getenv("NO_PROXY", "googleapis.com,.googleapis.com,10.250.0.1,10.0.0.0/8,metadata.google.internal,169.254.169.254,localhost,127.0.0.1")
os.environ["NO_PROXY"] = no_proxy_setting
os.environ["no_proxy"] = no_proxy_setting


def get_external_ip():
    try:
        req = urllib.request.urlopen("https://api.ipify.org/", timeout=10)
        ext_ip = req.read().decode("utf-8").strip()
    except Exception as e:
        ext_ip = f"error: {str(e)}"

    yield Event(
        content=types.Content(
            role="model",
            parts=[types.Part.from_text(text=f"my external ip is {ext_ip}")],
        ),
        output=None,
    )


root_agent = Workflow(
    name="wf_agent",
    edges=[
        ("START", get_external_ip),
    ],
)
# root_agent = Agent(
#     model="gemini-3.8-flash",
#     name="root_agent",
#     description="A helpful assistant for user questions.",
#     instruction="Answer user questions to the best of your knowledge",
# )

