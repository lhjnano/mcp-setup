# OpenCode MCP Server Setup

OpenCode에서 사용할 MCP(Model Context Protocol) 서버를 설정하는 도구입니다.

## 빠른 시작

### 1. 이 폴더를 원하는 위치에 복사
```bash
cp -r mcp-setup /your/desired/path/
```

### 2. 폴더로 이동
```bash
cd /your/desired/path/mcp-setup
```

### 3. 설치 스크립트 실행
```bash
# 기본 경로 사용 (~/.config/opencode/opencode.json)
chmod +x setup.sh
./setup.sh

# 또는 opencode 설정파일 경로 직접 지정
./setup.sh /path/to/opencode/config.json
```

설치 스크립트는 다음을 자동으로 수행합니다:
- OpenCode 설정파일 백업
- MCP 서버 선택 및 설치
- 설정파일 자동 업데이트

## 사용 가능한 MCP 서버

### 공식 MCP 서버

| 서버 | 패키지 | 설명 | 설정 |
|------|---------|------|------|
| **filesystem** | `@modelcontextprotocol/server-filesystem` | 안전한 파일 시스템 작업 | 디렉토리 경로 필요 |
| **memory** | `@modelcontextprotocol/server-memory` | 지식 그래프 기반 영구 메모리 | 없음 |
| **search** | `@otbossam/searxng-mcp-server` | SearXNG 메타검색 엔진을 통한 웹 검색 (Python/pip 필요) | |
| **puppeteer** | `@modelcontextprotocol/server-puppeteer` | Puppeteer를 통한 브라우저 자동화 | 없음 |

### 커뮤니티 MCP 서버

다음 커뮤니티 MCP 서버들도 사용 가능합니다 (수동 설정 필요):

| 서버 | 패키지 | 설명 |
|------|---------|------|
| **github** | `@modelcontextprotocol/server-github` | GitHub 저장소 및 이슈 접근 (공개 저장소는 토큰 선택적) |
| **git** | `@modelcontextprotocol/server-git` | Git 저장소 작업 및 이력 |

## 서버별 상세 설정

### 1. Filesystem MCP

**기능**: 안전한 파일 읽기/쓰기/검색 작업

**설정 예시**:
```json
{
  "mcp": {
    "filesystem": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "$HOME"]
    }
  }
}
```

### 2. Memory MCP

**기능**: 지식 그래프 기반 영구 메모리 시스템

**설정 예시**:
```json
{
  "mcp": {
    "memory": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-memory"]
    }
  }
}
```

### 3. SearXNG MCP

**기능**: SearXNG 메타검색 엔진을 통한 웹 검색 (Python/pip 필요)

**설정 예시**:
```json
{
  "mcp": {
    "search": {
      "type": "local",
      "command": ["python3", "-y", "$HOME/mcp-setup/search/search.py"],
    }
  }
}
```

**SearXNG 설치**:
```bash
docker run -d --name searxng -p 8080:8080 searxng/searxng
```

### 5. Puppeteer MCP

**기능**: 브라우저 자동화 및 웹 스크래핑

**설정 예시**:
```json
{
  "mcp": {
    "puppeteer": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-puppeteer"]
    }
  }
}
```

### 6. GitHub MCP (커뮤니티)

**기능**: GitHub 저장소 및 이슈 접근 (공개 저장소는 토큰 선택적)

**설정 예시**:
```json
{
  "mcp": {
    "github": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "optional-github-token"
      }
    }
  }
}
```

### 7. Git MCP (커뮤니티)

**기능**: Git 저장소 작업 및 이력

**설정 예시**:
```json
{
  "mcp": {
    "git": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-git", "$HOME/projects"]
    }
  }
}
```

## 수동 설정

자동 스크립트 대신 수동으로 설정하려면:

1. OpenCode 설정파일(`~/.config/opencode/opencode.json`) 열기
2. 원하는 MCP 서버 설정 추가
3. 필요한 환경변수 설정

### 완전한 설정 예시

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "filesystem": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "$HOME"]
    },
    "memory": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-memory"]
    },
    "search": {
      "type": "local",
      "command": ["python3", "-y", "$HOME/mcp-setup/search/search.py"],
    }
  }
}
```

## 다음 단계

### 1. OpenCode 재시작
설정을 적용하기 위해 OpenCode를 재시작합니다.

### 2. 환경변수 설정
API Key나 연결 문자열이 필요한 경우, 해당 환경변수를 설정합니다.

### 3. 첫 사용 시
서버들은 첫 사용 시 `npx`를 통해 자동으로 다운로드됩니다.

## 문제 해결

### "Command not found" 에러
- Node.js와 npm이 설치되어 있는지 확인하세요
- `node --version`과 `npm --version`으로 버전 확인

### 환경변수가 인식되지 않음
- `.bashrc` 또는 `.zshrc`에 환경변수를 추가
- `source ~/.bashrc`로 적용

### 백업 복구
설치 실패 시 백업 파일로 복구:
```bash
cp ~/.config/opencode/opencode.json.backup.YYYYMMDD_HHMMSS ~/.config/opencode/opencode.json
```

## 파일 구조

```
mcp-setup/
├── setup.sh              # 자동 설치 스크립트
├── README.md             # 이 파일
└── example-config.json   # 설정 예시
```

## 레퍼런스

- [MCP 공식 문서](https://modelcontextprotocol.io/)
- [MCP 서버 레지스트리](https://registry.modelcontextprotocol.io/)
- [MCP 서버 GitHub](https://github.com/modelcontextprotocol/servers)
