# RAG 데이터 수집 파이프라인: Google Drive -> Supabase Vector Store

> n8n, Gemini AI 및 Supabase를 활용한 자동화 문서 임베딩 및 벡터 저장소 구축 프로젝트

## 프로젝트 개요

| 항목 | 상세 내용 |
| ----- | ----- |
| **이름** | CANLAS NICOLE (칸라스 니콜) |
| **학번** | 2555039 |
| **학과** | 빅데이터과 2학년 |
| **과목** | 인공지능모델운용 (G952-2A0) |
| **워크플로우 엔진** | n8n (ngrok을 통한 터널링 연동) |
| **벡터 DB 및 모델** | Supabase (`pgvector`) & Google Gemini Embeddings |

## 파이프라인 아키텍처

```
[ Google Drive 폴더 ] ---> (트리거: 파일 생성/수정) ---> [ 파일 정보 정규화 ]
                                                              |
[ Supabase 벡터 DB ] <--- (벡터 저장) <--- [ 파일 다운로드 ] <--- [ 기존 청크 삭제 ]
          ^
          |--- [ Google Gemini 임베딩 ]
          +--- [ 기본 데이터 로더 ] <--- [ 재귀적 문자 텍스트 분할기 ]
```

## 슬라이드 1: 주요 목표

본 프로젝트는 실시간 Retrieval-Augmented Generation (RAG) 데이터 수집 파이프라인 구축을 목표로 합니다. Google Drive 내 파일의 생성 및 변경 사항을 지속적으로 감지하여, Supabase에 저장된 기존 데이터 청크를 자동으로 삭제 처리합니다. 이후 본문 텍스트를 추출해 최적의 단위($1,000$자 길이, $200$자 중첩)로 분할한 뒤 Google Gemini 임베딩 모델을 거쳐 벡터 데이터베이스에 저장합니다.

## 슬라이드 2: 기술 스택 및 시스템 구성요소

| 분류 | 구성요소 | 설명 |
| ----- | ----- | ----- |
| **자동화 엔진** | `n8n` | 로컬 환경에서 실행되는 로우코드 워크플로우 자동화 툴 |
| **터널링** | `ngrok` | 로컬 n8n 웹후크 엔드포인트를 외부로 노출하는 보안 HTTP 터널 |
| **스토리지 트리거** | `Google Drive API` | 지정된 폴더를 1분 간격으로 모니터링하여 새 파일 및 수정 사항 감지 |
| **벡터 데이터베이스** | `Supabase (pgvector)` | 벡터 유사도 검색을 지원하는 Postgres 기반 벡터 저장소 |
| **임베딩 모델** | `Google Gemini` | 텍스트 데이터를 벡터 수치로 변환하는 AI 임베딩 모델 |
| **텍스트 분할기** | `Recursive Character` | 본문 텍스트를 $1,000$자 단위(중첩 $200$자)로 분할 |

## 슬라이드 3: 워크플로우 세부 프로세스

### 1. Google Drive 트리거 (파일 생성 / 업데이트)

* **폴링 주기:** 1분마다 실행
* **주요 기능:** 지정된 Google Drive 폴더 URL을 감지하여 신규 업로드 또는 수정된 문서를 수집

### 2. 메타데이터 정규화 (`Normalize File Info`)

* `fileId`, `fileName`, `mimeType`, `fileUrl`, `modifiedTime` 변수 데이터 규격화

### 3. 중복 방지 처리 (`Delete Old Chunks`)

* 분할 및 저장 전 Supabase Postgres에 SQL 쿼리 실행:

  ```sql
  WITH deleted AS (
    DELETE FROM documents
    WHERE metadata->>'file_id' = $1
    RETURNING 1
  )
  SELECT count(*) AS deleted_chunks FROM deleted;
  ```

* 파일 수정 후 재업로드 시 데이터 중복 누적 방지

### 4. 데이터 처리 및 벡터화 (`Supabase Vector Store`)

* 문서를 다운로드 (Google Docs -> 일반 텍스트 변환)
* `Recursive Character Text Splitter`를 사용하여 텍스트 분할 ($1,000$자 크기, $200$자 중첩)
* `Embeddings Google Gemini`를 통해 벡터 임베딩 생성
* 생성된 벡터 데이터 및 메타데이터를 Supabase `documents` 테이블에 저장

## 슬라이드 4: 테스트 및 웹후크 연동

### 1. ngrok 터널 설정

```bash
ngrok config add-authtoken <YOUR_AUTHTOKEN>
ngrok http 5678
```

### 2. Postman 웹후크 이벤트 트리거

* **요청 방식:** `POST`
* **요청 URL:** `https://<your-ngrok-domain>.ngrok-free.dev/webhook-test/test`
* **전송 데이터 (JSON):**

  ```json
  {
    "message": "Workflow was started"
  }
  ```

## 사전 설정 사항

1. Supabase SQL Editor에서 `supabase-setup.sql`을 실행하여 `vector` 확장 기능 및 테이블 생성
2. n8n 내 필수 자격 증명(Credentials) 연결:
   * Google Drive OAuth2
   * PostgreSQL / Supabase API
   * Google Gemini API Key

## 제출 및 작성자 정보

* **작성자:** CANLAS NICOLE (칸라스 니콜 / 2555039)
* **과목명:** 인공지능모델운용 (G952-2A0)
* **GitHub 리포지토리:** [n8n-Practice](https://github.com/canlasnicole/n8n-Practice)