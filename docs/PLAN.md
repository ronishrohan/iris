# Iris — Implementation Plan

**Goal:** A locally-running voice assistant that literally replaces Siri on macOS — always listening for "Hey Iris", transcribes speech, reasons with an LLM, executes real tools, and speaks back.

**Architecture:**
```
mic → wake word (pvporcupine) → record until silence → faster-whisper STT
→ LLM brain (pluggable: DeepSeek API / Ollama) with tool calling
→ tool execution (shell, reminders, notes, calendar, spotify, messages, web)
→ TTS (edge-tts / macOS say) → speaker
```

**Tech Stack:**
- Python 3.11+ managed with `uv`
- `pvporcupine` — always-on wake word detection
- `faster-whisper` — local STT
- `sounddevice` + `soundfile` — audio capture/playback
- `edge-tts` — TTS (fallback: `say` via subprocess)
- LLM: DeepSeek API (default) or Ollama (local) — pluggable via provider abstraction
- Config: `~/.iris/config.toml` — BYOK, name, provider, wake phrase
- `launchd` plist — runs as a daemon on login

---

## Phase 1 — Project Scaffold

### Task 1: Init project structure with uv

```bash
cd ~/dev/personal/iris
uv init --name iris --python 3.11
mkdir -p iris/{core,providers,tools,tts}
touch iris/__init__.py iris/core/__init__.py iris/providers/__init__.py iris/tools/__init__.py iris/tts/__init__.py
```

**Directory layout:**
```
iris/
├── iris/
│   ├── core/
│   │   ├── listener.py       # wake word + audio capture
│   │   ├── brain.py          # LLM orchestrator + tool dispatch
│   │   └── config.py         # config loader
│   ├── providers/
│   │   ├── base.py           # abstract LLM provider
│   │   ├── deepseek.py       # DeepSeek API provider
│   │   └── ollama.py         # Ollama local provider
│   ├── tools/
│   │   ├── shell.py          # run terminal commands
│   │   ├── reminders.py      # Apple Reminders via AppleScript
│   │   ├── calendar.py       # Apple Calendar via AppleScript
│   │   ├── messages.py       # iMessage via AppleScript
│   │   ├── spotify.py        # Spotify via CLI/AppleScript
│   │   ├── web.py            # web search
│   │   └── registry.py       # tool registry — maps names to callables
│   ├── tts/
│   │   ├── base.py           # abstract TTS
│   │   ├── edge.py           # edge-tts
│   │   └── say.py            # macOS say fallback
│   └── main.py               # entrypoint
├── scripts/
│   └── install_launchd.py    # generates + installs launchd plist
├── docs/
│   └── PLAN.md
├── pyproject.toml
└── README.md
```

**Commit:** `chore: init project structure`

---

### Task 2: pyproject.toml with all deps

`pyproject.toml`:
```toml
[project]
name = "iris"
version = "0.1.0"
description = "A better Siri for macOS"
requires-python = ">=3.11"
dependencies = [
    "pvporcupine>=3.0.0",
    "faster-whisper>=1.0.0",
    "sounddevice>=0.4.6",
    "soundfile>=0.12.1",
    "edge-tts>=6.1.9",
    "openai>=1.0.0",         # DeepSeek is OpenAI-compatible
    "httpx>=0.27.0",          # Ollama calls
    "tomllib>=2.0.0",         # config parsing (stdlib in 3.11+)
    "typer>=0.12.0",          # CLI (iris setup, iris start, iris stop)
    "rich>=13.0.0",           # pretty output
]

[project.scripts]
iris = "iris.cli:app"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

```bash
uv sync
```

**Commit:** `chore: add dependencies`

---

## Phase 2 — Config System

### Task 3: Config schema + loader (`iris/core/config.py`)

Config lives at `~/.iris/config.toml`. Created on first `iris setup`.

```python
# iris/core/config.py
from __future__ import annotations
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

CONFIG_PATH = Path.home() / ".iris" / "config.toml"

@dataclass
class Config:
    name: str = "Iris"
    wake_phrase: str = "hey iris"          # what to listen for
    provider: str = "deepseek"             # "deepseek" | "ollama"
    model: str = "deepseek-chat"
    api_key: str = ""                      # BYOK — deepseek key
    ollama_host: str = "http://localhost:11434"
    ollama_model: str = "llama3.2"
    tts_engine: str = "edge"              # "edge" | "say"
    tts_voice: str = "en-US-AriaNeural"
    porcupine_access_key: str = ""        # picovoice free tier key
    silence_threshold_seconds: float = 1.5
    max_recording_seconds: float = 30.0

def load_config() -> Config:
    if not CONFIG_PATH.exists():
        return Config()
    with open(CONFIG_PATH, "rb") as f:
        data = tomllib.load(f)
    return Config(**{k: v for k, v in data.items() if k in Config.__dataclass_fields__})
```

**Commit:** `feat: config loader`

---

### Task 4: `iris setup` CLI command

Creates `~/.iris/config.toml` interactively.

```python
# iris/cli.py
import typer
from rich import print
from rich.prompt import Prompt
from pathlib import Path
import tomllib, os

app = typer.Typer()

@app.command()
def setup():
    """First-time setup — configure Iris."""
    config_dir = Path.home() / ".iris"
    config_dir.mkdir(exist_ok=True)
    
    name = Prompt.ask("What should I call myself?", default="Iris")
    wake_phrase = Prompt.ask("Wake phrase", default=f"hey {name.lower()}")
    provider = Prompt.ask("LLM provider", choices=["deepseek", "ollama"], default="deepseek")
    
    config = {"name": name, "wake_phrase": wake_phrase, "provider": provider}
    
    if provider == "deepseek":
        api_key = Prompt.ask("DeepSeek API key", password=True)
        model = Prompt.ask("Model", default="deepseek-chat")
        config.update({"api_key": api_key, "model": model})
    else:
        ollama_model = Prompt.ask("Ollama model", default="llama3.2")
        config["ollama_model"] = ollama_model
    
    pkey = Prompt.ask("Picovoice access key (free at console.picovoice.ai)")
    config["porcupine_access_key"] = pkey
    
    tts = Prompt.ask("TTS engine", choices=["edge", "say"], default="edge")
    config["tts_engine"] = tts
    
    # write toml manually (no tomli-w dep)
    lines = [f'{k} = {repr(v)}' for k, v in config.items()]
    (config_dir / "config.toml").write_text("\n".join(lines))
    print(f"[green]✓[/green] Config saved to ~/.iris/config.toml")

@app.command()
def start():
    """Start Iris."""
    from iris.main import run
    run()

@app.command()  
def stop():
    """Stop Iris daemon."""
    import subprocess
    subprocess.run(["launchctl", "unload", str(Path.home() / "Library/LaunchAgents/dev.iris.plist")])
```

**Commit:** `feat: iris setup CLI`

---

## Phase 3 — LLM Providers

### Task 5: Base provider interface (`iris/providers/base.py`)

```python
# iris/providers/base.py
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any

@dataclass
class Message:
    role: str   # "system" | "user" | "assistant" | "tool"
    content: str
    tool_calls: list[dict] | None = None
    tool_call_id: str | None = None

@dataclass
class ToolCall:
    id: str
    name: str
    arguments: dict

@dataclass
class LLMResponse:
    content: str | None
    tool_calls: list[ToolCall]
    done: bool  # False if more tool calls pending

class BaseProvider(ABC):
    @abstractmethod
    def chat(self, messages: list[Message], tools: list[dict]) -> LLMResponse:
        ...
```

**Commit:** `feat: base LLM provider interface`

---

### Task 6: DeepSeek provider (`iris/providers/deepseek.py`)

DeepSeek is OpenAI-compatible — use `openai` SDK with a custom base URL.

```python
# iris/providers/deepseek.py
from openai import OpenAI
from .base import BaseProvider, Message, LLMResponse, ToolCall
import json

class DeepSeekProvider(BaseProvider):
    def __init__(self, api_key: str, model: str = "deepseek-chat"):
        self.client = OpenAI(
            api_key=api_key,
            base_url="https://api.deepseek.com"
        )
        self.model = model

    def chat(self, messages: list[Message], tools: list[dict]) -> LLMResponse:
        oai_msgs = []
        for m in messages:
            msg = {"role": m.role, "content": m.content}
            if m.tool_calls:
                msg["tool_calls"] = m.tool_calls
            if m.tool_call_id:
                msg["tool_call_id"] = m.tool_call_id
            oai_msgs.append(msg)

        resp = self.client.chat.completions.create(
            model=self.model,
            messages=oai_msgs,
            tools=tools or None,
        )
        choice = resp.choices[0]
        msg = choice.message
        
        tool_calls = []
        if msg.tool_calls:
            for tc in msg.tool_calls:
                tool_calls.append(ToolCall(
                    id=tc.id,
                    name=tc.function.name,
                    arguments=json.loads(tc.function.arguments)
                ))
        
        return LLMResponse(
            content=msg.content,
            tool_calls=tool_calls,
            done=choice.finish_reason != "tool_calls"
        )
```

**Commit:** `feat: DeepSeek provider`

---

### Task 7: Ollama provider (`iris/providers/ollama.py`)

```python
# iris/providers/ollama.py
import httpx, json
from .base import BaseProvider, Message, LLMResponse, ToolCall

class OllamaProvider(BaseProvider):
    def __init__(self, host: str = "http://localhost:11434", model: str = "llama3.2"):
        self.host = host
        self.model = model

    def chat(self, messages: list[Message], tools: list[dict]) -> LLMResponse:
        payload = {
            "model": self.model,
            "messages": [{"role": m.role, "content": m.content} for m in messages],
            "stream": False,
        }
        if tools:
            payload["tools"] = tools
        
        resp = httpx.post(f"{self.host}/api/chat", json=payload, timeout=60)
        resp.raise_for_status()
        data = resp.json()
        msg = data["message"]
        
        tool_calls = []
        for tc in msg.get("tool_calls") or []:
            tool_calls.append(ToolCall(
                id=tc.get("id", "tc0"),
                name=tc["function"]["name"],
                arguments=tc["function"]["arguments"]
            ))
        
        return LLMResponse(
            content=msg.get("content"),
            tool_calls=tool_calls,
            done=data.get("done_reason") != "tool_calls"
        )
```

**Commit:** `feat: Ollama provider`

---

### Task 8: Provider factory

```python
# iris/providers/__init__.py
from .base import BaseProvider
from iris.core.config import Config

def get_provider(config: Config) -> BaseProvider:
    if config.provider == "deepseek":
        from .deepseek import DeepSeekProvider
        return DeepSeekProvider(api_key=config.api_key, model=config.model)
    elif config.provider == "ollama":
        from .ollama import OllamaProvider
        return OllamaProvider(host=config.ollama_host, model=config.ollama_model)
    raise ValueError(f"Unknown provider: {config.provider}")
```

**Commit:** `feat: provider factory`

---

## Phase 4 — Tools Layer

### Task 9: Tool registry (`iris/tools/registry.py`)

```python
# iris/tools/registry.py
from typing import Callable
from dataclasses import dataclass

@dataclass
class Tool:
    name: str
    description: str
    parameters: dict          # JSON Schema for args
    fn: Callable

_tools: dict[str, Tool] = {}

def register(name: str, description: str, parameters: dict):
    def decorator(fn: Callable):
        _tools[name] = Tool(name=name, description=description, parameters=parameters, fn=fn)
        return fn
    return decorator

def get_all_schemas() -> list[dict]:
    return [
        {"type": "function", "function": {"name": t.name, "description": t.description, "parameters": t.parameters}}
        for t in _tools.values()
    ]

def call(name: str, arguments: dict) -> str:
    if name not in _tools:
        return f"Error: tool '{name}' not found"
    try:
        result = _tools[name].fn(**arguments)
        return str(result)
    except Exception as e:
        return f"Error: {e}"
```

**Commit:** `feat: tool registry`

---

### Task 10: Shell tool (`iris/tools/shell.py`)

```python
# iris/tools/shell.py
import subprocess
from .registry import register

@register(
    name="run_command",
    description="Run a shell command on the user's Mac and return output. Use for file operations, git, brew, etc.",
    parameters={
        "type": "object",
        "properties": {
            "command": {"type": "string", "description": "Shell command to run"}
        },
        "required": ["command"]
    }
)
def run_command(command: str) -> str:
    result = subprocess.run(command, shell=True, capture_output=True, text=True, timeout=30)
    out = result.stdout.strip() or result.stderr.strip() or "(no output)"
    return out[:2000]  # cap output
```

**Commit:** `feat: shell tool`

---

### Task 11: Apple Reminders tool (`iris/tools/reminders.py`)

```python
# iris/tools/reminders.py
import subprocess
from .registry import register

def _run_applescript(script: str) -> str:
    result = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
    return result.stdout.strip() or result.stderr.strip()

@register(
    name="add_reminder",
    description="Add a reminder to Apple Reminders",
    parameters={
        "type": "object",
        "properties": {
            "title": {"type": "string"},
            "due_date": {"type": "string", "description": "ISO date string, optional"}
        },
        "required": ["title"]
    }
)
def add_reminder(title: str, due_date: str = "") -> str:
    script = f'tell application "Reminders" to make new reminder with properties {{name:"{title}"}}'
    _run_applescript(script)
    return f"Reminder added: {title}"

@register(
    name="list_reminders",
    description="List upcoming reminders from Apple Reminders",
    parameters={"type": "object", "properties": {}, "required": []}
)
def list_reminders() -> str:
    script = '''
    tell application "Reminders"
      set output to ""
      repeat with r in (reminders whose completed is false)
        set output to output & name of r & "\n"
      end repeat
      return output
    end tell
    '''
    return _run_applescript(script) or "No reminders"
```

**Commit:** `feat: reminders tool`

---

### Task 12: iMessage tool (`iris/tools/messages.py`)

```python
# iris/tools/messages.py
import subprocess
from .registry import register

@register(
    name="send_imessage",
    description="Send an iMessage to a contact",
    parameters={
        "type": "object",
        "properties": {
            "recipient": {"type": "string", "description": "Phone number or contact name"},
            "message": {"type": "string"}
        },
        "required": ["recipient", "message"]
    }
)
def send_imessage(recipient: str, message: str) -> str:
    script = f'''
    tell application "Messages"
      set targetBuddy to "{recipient}"
      set targetService to 1st account whose service type = iMessage
      send "{message}" to participant targetBuddy of targetService
    end tell
    '''
    subprocess.run(["osascript", "-e", script], capture_output=True)
    return f"Message sent to {recipient}"
```

**Commit:** `feat: iMessage tool`

---

### Task 13: Spotify tool (`iris/tools/spotify.py`)

```python
# iris/tools/spotify.py
import subprocess
from .registry import register

def _spotify(cmd: str) -> str:
    script = f'tell application "Spotify" to {cmd}'
    r = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
    return r.stdout.strip()

@register("spotify_play", "Play a song or artist on Spotify", {
    "type": "object",
    "properties": {"query": {"type": "string", "description": "Song, artist, or album name"}},
    "required": ["query"]
})
def spotify_play(query: str) -> str:
    # search via spotify URI — fallback to just playing/resuming
    _spotify("play")
    return f"Playing on Spotify"

@register("spotify_control", "Control Spotify playback", {
    "type": "object",
    "properties": {"action": {"type": "string", "enum": ["pause", "next", "previous", "play"]}},
    "required": ["action"]
})
def spotify_control(action: str) -> str:
    _spotify(action)
    return f"Spotify: {action}"
```

**Commit:** `feat: spotify tool`

---

### Task 14: Web search tool (`iris/tools/web.py`)

```python
# iris/tools/web.py
import httpx
from .registry import register

@register(
    name="web_search",
    description="Search the web and return a brief answer",
    parameters={
        "type": "object",
        "properties": {"query": {"type": "string"}},
        "required": ["query"]
    }
)
def web_search(query: str) -> str:
    # DuckDuckGo instant answers API — no key needed
    resp = httpx.get(
        "https://api.duckduckgo.com/",
        params={"q": query, "format": "json", "no_html": 1, "skip_disambig": 1},
        timeout=10
    )
    data = resp.json()
    answer = data.get("AbstractText") or data.get("Answer") or ""
    related = [r["Text"] for r in data.get("RelatedTopics", [])[:3] if "Text" in r]
    if not answer and not related:
        return f"No instant answer found for: {query}"
    return (answer + "\n" + "\n".join(related)).strip()[:1000]
```

**Commit:** `feat: web search tool`

---

## Phase 5 — STT

### Task 15: Audio capture (`iris/core/listener.py` — audio part)

```python
# iris/core/listener.py
import sounddevice as sd
import numpy as np
import tempfile, soundfile as sf
from faster_whisper import WhisperModel
from iris.core.config import Config

SAMPLE_RATE = 16000

class AudioCapture:
    def __init__(self, config: Config):
        self.silence_threshold = config.silence_threshold_seconds
        self.max_seconds = config.max_recording_seconds
        self._model = None

    def _load_model(self):
        if not self._model:
            self._model = WhisperModel("base.en", device="cpu", compute_type="int8")
        return self._model

    def record_until_silence(self) -> np.ndarray:
        """Record audio until user stops speaking."""
        chunk_size = int(SAMPLE_RATE * 0.1)   # 100ms chunks
        silence_chunks = int(self.silence_threshold / 0.1)
        max_chunks = int(self.max_seconds / 0.1)
        
        frames = []
        silent_count = 0
        
        with sd.InputStream(samplerate=SAMPLE_RATE, channels=1, dtype="float32") as stream:
            for _ in range(max_chunks):
                chunk, _ = stream.read(chunk_size)
                frames.append(chunk.copy())
                rms = np.sqrt(np.mean(chunk**2))
                if rms < 0.01:    # silence threshold
                    silent_count += 1
                    if silent_count >= silence_chunks and len(frames) > 10:
                        break
                else:
                    silent_count = 0
        
        return np.concatenate(frames, axis=0).flatten()

    def transcribe(self, audio: np.ndarray) -> str:
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            sf.write(f.name, audio, SAMPLE_RATE)
            model = self._load_model()
            segments, _ = model.transcribe(f.name, language="en")
            return " ".join(s.text for s in segments).strip()
```

**Commit:** `feat: audio capture + whisper STT`

---

## Phase 6 — Wake Word Detection

### Task 16: Porcupine wake word listener (`iris/core/listener.py` — wake part)

Porcupine has a built-in "Hey Google"-style model. For "Hey Iris" specifically, get a custom `.ppn` model from [console.picovoice.ai](https://console.picovoice.ai) (free account).

```python
# iris/core/listener.py (continued)
import pvporcupine
import struct

class WakeWordListener:
    def __init__(self, config: Config):
        self.config = config
        self._porcupine = None

    def _init_porcupine(self):
        # Custom "Hey Iris" .ppn keyword file goes in ~/.iris/hey-iris.ppn
        # Falls back to built-in "hey siri" equivalent if not found
        import os
        ppn_path = os.path.expanduser("~/.iris/hey-iris.ppn")
        
        kwargs = dict(access_key=self.config.porcupine_access_key, sensitivity=0.5)
        if os.path.exists(ppn_path):
            kwargs["keyword_paths"] = [ppn_path]
        else:
            kwargs["keywords"] = ["hey siri"]   # fallback during dev
        
        self._porcupine = pvporcupine.create(**kwargs)

    def wait_for_wake_word(self):
        """Block until wake word detected."""
        if not self._porcupine:
            self._init_porcupine()
        
        frame_length = self._porcupine.frame_length
        
        with sd.RawInputStream(
            samplerate=self._porcupine.sample_rate,
            channels=1,
            dtype="int16",
            blocksize=frame_length
        ) as stream:
            print("👂 Listening for wake word...")
            while True:
                data, _ = stream.read(frame_length)
                pcm = struct.unpack_from("h" * frame_length, bytes(data))
                result = self._porcupine.process(pcm)
                if result >= 0:
                    print("🟢 Wake word detected!")
                    return
```

**Commit:** `feat: porcupine wake word detection`

---

## Phase 7 — TTS

### Task 17: TTS engines

```python
# iris/tts/edge.py
import edge_tts, asyncio, tempfile, subprocess

class EdgeTTS:
    def __init__(self, voice: str = "en-US-AriaNeural"):
        self.voice = voice

    def speak(self, text: str):
        async def _speak():
            with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as f:
                comm = edge_tts.Communicate(text, self.voice)
                await comm.save(f.name)
                subprocess.run(["afplay", f.name])   # macOS native audio player
        asyncio.run(_speak())
```

```python
# iris/tts/say.py
import subprocess

class SayTTS:
    def speak(self, text: str):
        subprocess.run(["say", text])
```

```python
# iris/tts/__init__.py
from iris.core.config import Config

def get_tts(config: Config):
    if config.tts_engine == "edge":
        from .edge import EdgeTTS
        return EdgeTTS(voice=config.tts_voice)
    from .say import SayTTS
    return SayTTS()
```

**Commit:** `feat: TTS engines (edge-tts + macOS say)`

---

## Phase 8 — Brain (LLM Orchestrator)

### Task 18: Brain — agentic loop with tool calling (`iris/core/brain.py`)

```python
# iris/core/brain.py
from iris.providers.base import BaseProvider, Message
from iris.tools import registry
from iris.core.config import Config

SYSTEM_PROMPT = """You are Iris, a voice assistant running on the user's Mac.
You replace Siri. Be concise — your responses will be spoken aloud, so no markdown, no bullet points, no code blocks.
One to three sentences max unless asked for more.
You have tools to take real actions: run commands, send messages, set reminders, control Spotify, search the web.
When you use a tool, confirm briefly what you did. Don't ask for permission — just do it."""

class Brain:
    def __init__(self, provider: BaseProvider, config: Config):
        self.provider = provider
        self.config = config
        self.history: list[Message] = []
        self.tools = registry.get_all_schemas()
        self.system = Message(role="system", content=SYSTEM_PROMPT.replace("Iris", config.name))

    def think(self, user_input: str) -> str:
        self.history.append(Message(role="user", content=user_input))
        messages = [self.system] + self.history
        
        # agentic loop — keep going until no more tool calls
        for _ in range(10):   # max 10 tool calls per turn
            response = self.provider.chat(messages, self.tools)
            
            if response.tool_calls:
                # execute each tool call
                tool_msg = Message(
                    role="assistant",
                    content=response.content or "",
                    tool_calls=[{"id": tc.id, "type": "function", "function": {"name": tc.name, "arguments": str(tc.arguments)}} for tc in response.tool_calls]
                )
                messages.append(tool_msg)
                
                for tc in response.tool_calls:
                    result = registry.call(tc.name, tc.arguments)
                    messages.append(Message(
                        role="tool",
                        content=result,
                        tool_call_id=tc.id
                    ))
            
            if response.done:
                final = response.content or "Done."
                self.history.append(Message(role="assistant", content=final))
                return final
        
        return "I ran into an issue completing that."
```

**Commit:** `feat: brain — agentic LLM loop with tool calling`

---

## Phase 9 — Main Loop

### Task 19: Main entrypoint (`iris/main.py`)

```python
# iris/main.py
from iris.core.config import load_config
from iris.core.listener import WakeWordListener, AudioCapture
from iris.providers import get_provider
from iris.core.brain import Brain
from iris.tts import get_tts
import iris.tools.shell      # noqa — registers tools
import iris.tools.reminders  # noqa
import iris.tools.messages   # noqa
import iris.tools.spotify    # noqa
import iris.tools.web        # noqa

def run():
    config = load_config()
    
    wake = WakeWordListener(config)
    audio = AudioCapture(config)
    brain = Brain(get_provider(config), config)
    tts = get_tts(config)
    
    print(f"🌸 {config.name} is running. Say '{config.wake_phrase}' to activate.")
    
    while True:
        try:
            wake.wait_for_wake_word()
            tts.speak("Mmm?")          # acknowledgement chime / word
            
            audio_data = audio.record_until_silence()
            transcript = audio.transcribe(audio_data)
            
            if not transcript.strip():
                continue
            
            print(f"[you] {transcript}")
            response = brain.think(transcript)
            print(f"[iris] {response}")
            tts.speak(response)
        
        except KeyboardInterrupt:
            print("Goodbye.")
            break
        except Exception as e:
            print(f"Error: {e}")
            continue
```

**Commit:** `feat: main loop — wake → transcribe → think → speak`

---

## Phase 10 — launchd Daemon

### Task 20: launchd plist installer (`scripts/install_launchd.py`)

Makes Iris start automatically on login, running silently in the background.

```python
# scripts/install_launchd.py
import subprocess, os
from pathlib import Path

PLIST_ID = "dev.iris.agent"
PLIST_PATH = Path.home() / "Library/LaunchAgents" / f"{PLIST_ID}.plist"
IRIS_BIN = subprocess.run(["which", "iris"], capture_output=True, text=True).stdout.strip()
LOG_DIR = Path.home() / ".iris" / "logs"
LOG_DIR.mkdir(exist_ok=True)

PLIST = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>{PLIST_ID}</string>
    <key>ProgramArguments</key>
    <array>
        <string>{IRIS_BIN}</string>
        <string>start</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>{LOG_DIR}/iris.log</string>
    <key>StandardErrorPath</key>
    <string>{LOG_DIR}/iris.err</string>
</dict>
</plist>"""

PLIST_PATH.write_text(PLIST)
subprocess.run(["launchctl", "load", str(PLIST_PATH)])
print(f"✓ Iris installed as launchd agent — starts on login")
print(f"  Logs: {LOG_DIR}/iris.log")
```

**Add `iris install` CLI command:**
```python
@app.command()
def install():
    """Install Iris as a launchd daemon (starts on login)."""
    import runpy
    runpy.run_path("scripts/install_launchd.py")
```

**Commit:** `feat: launchd daemon installer`

---

## Phase 11 — README

### Task 21: README.md

```markdown
# iris 🌸

A better Siri for your Mac. Always listening, locally running, actually capable.

## Features
- 🎤 Always-on wake word detection ("Hey Iris")
- 🧠 Pluggable LLM brain — DeepSeek API (default) or local Ollama
- 🔧 Real tools: shell commands, Apple Reminders, iMessage, Spotify, web search
- 🔊 Natural TTS via edge-tts or macOS `say`
- 🚀 Runs as a launchd daemon — starts with your Mac

## Install

```bash
# clone
git clone https://github.com/ronishrohan/iris ~/dev/personal/iris
cd ~/dev/personal/iris

# install deps
uv sync

# configure
iris setup

# run
iris start

# or install as daemon (starts on login)
iris install
```

## Config

Config lives at `~/.iris/config.toml`. Run `iris setup` to generate it.

| Key | Default | Description |
|-----|---------|-------------|
| `name` | `Iris` | Assistant name (also the wake word) |
| `wake_phrase` | `hey iris` | Wake phrase |
| `provider` | `deepseek` | `deepseek` or `ollama` |
| `api_key` | — | DeepSeek API key (BYOK) |
| `tts_engine` | `edge` | `edge` or `say` |

## Wake Word

Get a free "Hey Iris" `.ppn` model from [console.picovoice.ai](https://console.picovoice.ai) and save it to `~/.iris/hey-iris.ppn`.
```

**Commit:** `docs: README`

---

## Build Order Summary

```
Phase 1: scaffold + deps          → iris/ structure, pyproject.toml
Phase 2: config                   → config.py, iris setup CLI
Phase 3: providers                → base, deepseek, ollama, factory
Phase 4: tools                    → registry, shell, reminders, messages, spotify, web
Phase 5: STT                      → audio capture, faster-whisper
Phase 6: wake word                → pvporcupine
Phase 7: TTS                      → edge-tts, say
Phase 8: brain                    → agentic loop
Phase 9: main loop                → wire everything together
Phase 10: launchd                 → daemon, iris install
Phase 11: README                  → docs
```

**Total commits:** ~21 focused commits, each independently testable.

---

## Open Questions (decide before/during build)

- [ ] **Custom wake word model**: get "hey-iris.ppn" from picovoice console — free, takes 2 min
- [ ] **Subscription model**: how to gate access behind a subscription (future)
- [ ] **Multi-turn context**: how many turns to keep in `brain.history` before pruning
- [ ] **Interrupt handling**: can user interrupt Iris mid-speech? (needs async)
- [ ] **Audio feedback**: play a chime (not speak) on wake detection?
