# KnHCommunity — GitHub Pages edition

GitHub Pages는 HTML/CSS/JavaScript 정적 파일만 호스팅합니다. 여러 사용자의 계정, 문서, 게시글, 토론을 공유하려면 별도 백엔드가 필요하므로 이 버전은 **GitHub Pages + Supabase** 구조입니다. Cloudflare Worker/D1는 사용하지 않습니다.

## 포함 기능

- 위키 문서 목록/작성/편집/내부 링크 `[[문서명]]`
- Markdown 렌더링(표, 코드, 목록, 인용문 등) 및 DOMPurify 정화
- KaTeX 수학 수식: `$...$`, `\(...\)`, `$$...$$`, `\[...\]`
- 수식 삽입 버튼과 미리보기
- 이미지 파일 선택/드래그 앤 드롭/붙여넣기 → Supabase Storage 업로드
- 이메일 회원가입/로그인/로그아웃, 프로필/닉네임/소개
- 자유게시판, 게시글, 댓글
- 실시간 토론 채널(general/wiki/free-talk/help), 답글, 메시지 삭제, 이모지 반응
- 7개 테마: Light, Dark, Ocean, Forest, Sunset, Sakura, Midnight
- 반응형 화면

## 1. Supabase 프로젝트 만들기

1. https://supabase.com 에서 새 프로젝트를 만듭니다.
2. Project Settings → API에서 Project URL과 **Publishable key**(또는 구형 프로젝트의 anon key)를 복사합니다.
3. Supabase → SQL Editor → New query에서 `supabase-setup.sql` 전체를 실행합니다.
4. Authentication → URL Configuration에서 Site URL에 GitHub Pages 주소를 등록합니다. 예: `https://USERNAME.github.io/REPOSITORY/`
5. 필요하면 Redirect URLs에도 위 주소를 추가합니다.
6. Authentication → Providers → Email에서 이메일 확인 설정을 확인합니다. 이메일 확인을 켜 두면 가입 후 메일 인증이 필요합니다.

## 2. 프런트엔드 연결

`assets/app.js` 맨 위의 두 값을 교체합니다.

```js
const SUPABASE_URL = 'https://프로젝트ID.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_...';
```

브라우저에 공개되는 Publishable/anon key만 사용하세요. **service_role / secret key는 절대 넣으면 안 됩니다.** 데이터 보호는 SQL에 포함된 RLS 정책이 담당합니다.

## 3. GitHub Pages 배포

1. GitHub에서 새 저장소를 만듭니다.
2. 이 폴더의 모든 파일을 저장소 루트에 업로드합니다.
3. 저장소 Settings → Pages → Build and deployment → Source에서 **GitHub Actions**를 선택합니다.
4. `main` 브랜치에 push하면 `.github/workflows/pages.yml`이 자동 배포합니다.
5. Actions 탭에서 Pages 배포가 완료됐는지 확인합니다.

또는 Pages의 Deploy from a branch로 `main / root`를 선택해도 됩니다.

## 4. 수식 입력 예시

인라인 수식:

```md
피타고라스 정리는 $a^2+b^2=c^2$ 이다.
```

블록 수식:

```md
$$
\\int_0^1 x^2\\,dx=\\frac13
$$
```

다른 예시:

```md
$$
\\begin{aligned}
E&=mc^2\\\\
(a+b)^2&=a^2+2ab+b^2
\\end{aligned}
$$
```

## 데이터/보안 관련 주의

- GitHub Pages는 정적 호스팅이고 사용자 데이터는 Supabase에 저장됩니다.
- `supabase-setup.sql`은 공개 읽기와 로그인 사용자 쓰기를 허용하도록 RLS를 설정합니다. 위키/게시글/메시지 수정·삭제는 현재 작성자만 가능합니다.
- 현재 화면의 토론 채널은 메시지 실시간 반영을 지원합니다. 메시지 수정, 스레드 접기, 관리자 도구, 신고/차단, 전체 알림은 아직 포함되지 않았습니다.
- 이 버전은 원래 사이트의 모든 3,000줄 코드를 그대로 포팅한 것이 아니라, GitHub Pages에서 동작하도록 핵심 커뮤니티 기능을 새 구조로 재구성한 버전입니다. 기존 페이지/문서 데이터는 자동 이전되지 않습니다.
- 외부 CDN(KaTeX, Marked, DOMPurify, Supabase JS)을 사용하므로 CDN 접속이 차단된 환경에서는 일부 기능이 작동하지 않을 수 있습니다.

## 문제 해결

- `Supabase 설정이 필요합니다`: `assets/app.js` URL/key placeholder를 실제 값으로 바꾸었는지 확인합니다.
- `relation does not exist`: SQL Editor에서 `supabase-setup.sql` 전체를 실행했는지 확인합니다.
- 회원가입 후 프로필 생성 오류: 닉네임이 이미 사용 중인지 확인합니다.
- 가입 후 로그인 안 됨: 이메일 확인이 켜져 있다면 인증 메일을 확인하고 Site URL/Redirect URL을 확인합니다.
- 토론이 갱신되지 않음: Realtime publication에 `discussion_messages`가 추가됐는지 확인합니다.
- 이미지 업로드 실패: Storage의 `community-images` 버킷과 Storage 정책이 생성됐는지 확인합니다.
