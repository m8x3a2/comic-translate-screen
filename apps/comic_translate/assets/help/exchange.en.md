# Exchange with a chat AI

## What it is and why

The exchange reads and translates through any chat AI: ChatGPT, Gemini, Claude, DeepSeek and others.
**The app sends nothing by itself.** It makes the pictures and the instructions, you carry them into the chat,
and you paste the chat's answer back: the app puts it into the bubbles.

Why:

- big chat AIs translate more naturally than the offline translator;
- many chats are free and need no API key;
- the chat sees the picture: it can read text the app read badly and tell who speaks.

How it differs from the "OpenRouter" translator: OpenRouter works by itself, over the network, with an API key
(Settings → Translator). The exchange is by hand, with no key, through the chat in your browser.

## How to open it

- The **"Chat"** button on the main screen (or its menu): **"Read and translate through a chat…"**,
  **"Read through a chat…"**, **"Translate through a chat…"**. It works on the selected pages.
- **"Translate all"** can open the exchange by itself too: choose **"By hand through a chat AI"** as the
  translator (Settings → Translator) and/or for reading (Settings → Recognition and cleaning). The app then finds
  the text on the pages, opens the exchange window, and after **"Apply and go on"** cleans and letters the pages.
- **"Chat → Open an earlier exchange…"** opens an exchange made before (see below).

## Modes

The mode is chosen at the top of the exchange window.

- **"Read"**: the chat reads the text from the pictures. Another translator (or the next exchange) translates it.
- **"Translate"**: the app has read the text already; the chat gets the text with labels only (pictures if you
  want). Works with chats that take no pictures.
- **"Read and translate"**: the chat reads and translates in one answer.

A window opened by "Translate all" has one mode: the one the settings need.

## Labels

Each bubble has a label: **`[01-003]`** is page 1, bubble 3. The page number is the page's place among all
pages of the project. Labels are on the pictures above each bubble, in the instructions and in the txt files.
The app tells by them which answer belongs to which bubble.

The chat answers with lines like:

- "Read" or "Translate": `[01-003] text`
- "Read and translate": `[01-003] I'M LATE! --> Я ОПОЗДАЛ!`

The mark between the original and the translation (`-->` by default) is set in the settings: **"Between the
original and the translation"**. Plain arrows `->`, `→` are understood too.

## Step by step

### 1. Send to the chat

1. Open the exchange window (the "Chat" button).
2. **"Copy the pictures"** → paste them into the chat: **Ctrl+V**. You can copy only some: tick them and the
   button becomes "Copy the picked". Each picture also has "Copy only this picture".
3. **"Copy the instructions"** → paste them into the chat and send.

In "Translate" there is also **"Copy the text"**: the `[01-003] text` lines alone, without instructions, for
people who write the chat their own.

Handy in this step:

- **The page picker** ("All pages" / "Page 1"…) shows the pictures of one page (with many pages).
- **"Open the pictures large"**: a big view of the pictures.
- **"Sheets"**: how many bubbles go on one picture (sheet): "as many as fit" or "a set number".
  **"Sheet size"**: 1600 dots suits most chats (chats shrink big pictures and small letters stop being readable).
- **"Own sheets"**: your own sheet borders, for example `1-4, 5-6` (bubbles numbered in order). The scissors
  icon does the same by clicking bubbles.
- **"Each page on new sheets"**: a sheet holds bubbles of one page only. Turns on by itself when you pick one
  page and the sheets are mixed.
- **"Picture of the page"**: a small picture of the whole page with the boxes labelled. It helps the chat see who
  speaks and what goes on. As its own picture or on the sheet.
- **"Instructions for the chat"** (opens up): the text of the instructions. You can change it for this time;
  **"Change for good…"** changes the template in the settings.

### 2. Paste the chat's answer

Copy the chat's whole answer (chats usually have a "Copy" button). Other text around the labelled lines does
no harm: the app takes only the lines with labels.

- **"Paste"** pastes the answer into the field.
- **"Take from the txt files"** takes what you wrote into the exchange txt files (see below).
- **"Open a txt file…"** takes the answer from any txt file.

Under the field the app tells what it found:

- **"Answers found: N of M"**: how many bubbles got an answer;
- **"No answer: …"**: bubbles the chat did not answer (you can send them again, see "Another round");
- **"Unchanged"**: lines that match what the bubble has already;
- **"Not sent"**: labels that were not in the exchange (the chat made a mistake);
- **"Answered twice"**: the first one counts.

You can turn on **"Offer the answer from the clipboard"** (Settings → Exchange with a chat AI, off by default):
you copy the answer in the chat, come back to the window, and the app offers to paste it.

### 3. Apply

**"Apply"** writes the answers into the bubbles. Bubbles without an answer stay as they are (or get the text of
the setting **"Text for pieces without an answer"**, for example ⟦empty⟧, so they are easy to find).

## The exchange txt files

**"Open the folder"** (at the bottom of the window) opens the exchange folder. It holds the pictures, the
instructions and three txt files. They are the same in every mode and show what the bubbles hold **now**:

- **`ALL.txt`**: `[01-001] text --> translation`;
- **`ALL_original.txt`**: the text from the picture only;
- **`ALL_translation.txt`**: the translation only;
- `page_01.txt`…: the same per page (if chosen in the "Text files" setting).

How to use them:

1. Open a file in Notepad (or any text editor).
2. Change any lines and save the file. You can also replace the whole of `ALL.txt` with the chat's answer.
3. In the exchange window press **"Take from the txt files"**.

Changed lines go into the bubbles, untouched lines change nothing. The app takes everything written: in
"Translate" you can fix the original too, in "Read" you can give the translation as well.

**"One text for every mode"** (on by default): what you wrote in the txt files stays when you switch the mode.
Off: each mode has clean files of its own.

## Who speaks

Helps the translation pick the gender (in Russian "я пришёл" or "я пришла").

- In the "Text" panel, on the card of a bubble: **"Who speaks — / M / F / N"** (N: no gender — a thing, a crowd,
  a narrator).
- The tag goes to the chat (`[01-003] [f] …`), into the instructions and to translators over the network
  (OpenRouter and others). The offline translator does not use it.
- Many bubbles are quicker to mark in the txt files: after the label `[m]` is a man, `[f]` a woman, `[n]` no
  gender, `[-]` removes the tag.

## Names and words (glossary)

How to translate names and words in this project. Open it with **"Chat → Names and words…"** or the
**"Glossary (N)"** button in the exchange window.

- One line, one word: `Kai --> Кай` (`->`, `→`, `=>` are understood too).
- Any other line is a note for the translation: "Don't translate senpai", "The heroes are on first-name terms".
- Lines with `#` are your own notes; they go nowhere.

The glossary is kept in the project. For "Translate" the instructions get only the words that are in the text
sent; when the chat reads pictures, the whole glossary. Translators over the network get it too.

The chat may suggest new names as lines `NEW: word --> translation`. The window shows them with ticks: press
**"Add to the glossary"**.

## Styles of translation

The **"Style of the translation"** chips in the exchange window: "No style" (the default), "Close to the
original", "Lively, spoken", "Soften rude words", "Rude words as strong", "Keep -san/-kun". You can pick several.

Your own styles: the icon by the label ("Own styles and instructions") or Settings → Exchange with a chat AI →
Styles of translation: a name and what to ask (in English: chats understand it best). Styles go into the
instructions and to translators over the network.

## Another round: "Send the missing ones" and "Ask again"

The chat answered not every bubble, or answered some badly: no need to start over.

- There is **"No answer: …"**: under the check of the answer you get the button **"Send the missing ones (N)"**.
- The chat answered all but some badly: write their labels into the **"Ask again"** field, separated by commas:
  `01-002, 03-005`. The button becomes **"Ask again (N)"** (or "Send the missing ones and ask again" with both).

On a press the app keeps the answers taken ("Taken from earlier answers: N of M"), clears the answer field and
makes a short request for these bubbles only: their pictures and instructions (in the exchange folder, a
subfolder `again_1`, `again_2`…). Send it **to the same chat** and paste the answer. The new answer replaces the
old one for these bubbles only. **"Apply"** writes all of it. **"Back to the whole exchange"** returns to the
first request.

## "Open an earlier exchange…"

The menu item **"Chat → Open an earlier exchange…"** (it used to be "Answer for an earlier exchange…").

**What it does.** You pick the folder of an exchange the app made before. The exchange window opens with the
same pages, mode, pictures and txt files. Nothing is made again.

**When you need it.** You sent the pictures to the chat and then closed the exchange window or the app. The
chat's answer came later (or you wrote it into the txt files). Open that exchange, paste the answer (or press
"Take from the txt files") and press "Apply".

**Where the exchanges are.** In the app's data folder, in `exchange`: on Windows
`%LOCALAPPDATA%\ComicTranslateScreen\exchange`. Each exchange is a folder named by its date and time, for
example `20261026_093015`. The last 20 are kept; older ones are removed.

**"Not an exchange folder".** The app says so when the folder has no `exchange.json`. Pick the dated folder
itself (not `exchange` and not the `again_1` subfolder).

The pages must be open in the app: the answer is written into the bubbles of the open project.

## Export text

**"Chat → Export text…"** (and a button in the "Export" window): the dialogues of the pages as plain text — the
original, the translation or both (then two files: `…_original.txt` and `…_translation.txt`). Keep them, or
attach them to the chat as context, for example the dialogues of earlier chapters. The labels are the same as
in the exchange. The right side shows how the file will look.

## Settings

Settings → Exchange with a chat AI:

- **"Read and translate in one message"**: when both go through the chat (on). Off: reading first, then a second
  round with the text.
- **"Original and translation as two lists"**: the chat writes all originals, then `===`, then all translations.
- **"Pictures"**: sheets, a picture for each bubble, or both; the sheet size; pictures in a folder.
- **"Text files"**: `ALL.txt`, a file for each page, or both.
- **"Instructions for the chat"**: your own instructions for each mode (in English; "Back to the built-in one"
  undoes them).

## Tips

- **Which chat.** Any that takes pictures: ChatGPT, Gemini, Claude, DeepSeek, Qwen and others. Some work without
  signing in, but then the limits are lower and pictures may not be taken — the terms change. If the chat takes
  no pictures, read the text with the app and use "Translate".
- **New chapter, new chat.** When answers in a long chat get worse or shorter, start a new one.
- **Many pages.** Send them in parts (say 5–10 pages): chats tire on long answers and skip bubbles. What is
  skipped is easy to send again.
- **The answer was cut off.** Ask the chat to "continue" and paste the rest together with the first part — or
  apply what there is and send the missing ones.
- **The chat answered with plain text, no labels.** Ask it to answer strictly as `[01-003] text`, one line per
  label. Labels without brackets (`01-003 text`) are understood.
- **Pictures can't be read.** Lower the "Sheet size", or choose "a set number" with fewer bubbles on a sheet.
