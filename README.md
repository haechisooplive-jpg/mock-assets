# mock-assets

라이브 목업 데이터 채우기 Figma 플러그인이 불러가는 정적 파일입니다. GitHub Pages 로 공개됩니다.
(AI 로 만든 이미지와 가짜 닉네임·제목만 들어 있습니다. 실제 개인정보를 넣지 마세요.)

- 주소: https://haechisooplive-jpg.github.io/mock-assets/
- 데이터: `mock-data.json` (스키마는 figma-plugin 저장소의 `sample-data/mock-data.json` 참고)
- 이미지: `images/general/`, `images/game/`, `images/profile/`
  - 섬네일 1280×720 JPG(150KB 이하), 프로필 400×400 JPG(40KB 이하)
  - 파일명 예: `general-01.jpg`, `game-01.jpg`, `profile-01.jpg`

## 이미지를 바꾸는 법
1. 이미지를 폴더에 넣고 `mock-data.json` 의 URL 목록을 맞춘다
   (예: `https://haechisooplive-jpg.github.io/mock-assets/images/general/general-01.jpg`)
2. `git add -A && git commit -m "Update assets" && git push`
3. 반영에는 최대 10분쯤 걸린다. `./check.sh` 로 응답을 확인한다.
