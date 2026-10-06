from google.adk.agents.llm_agent import Agent
from google.adk import Workflow
from google.genai import types
from google.adk.events.event import Event
import urllib.request


def get_external_ip():
    try:
        req = urllib.request.urlopen("https://api.ipify.org/", timeout=5)
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
