# Deploy using cli

```bash


uv sync
uv pip freeze > aenat/requirements.txt

adk deploy agent_engine aenat --project as-alf-argolis --region us-east1 
#--agent_engine_id projects/332822469566/locations/us-east1/reasoningEngines/531396168727396352
```
```
