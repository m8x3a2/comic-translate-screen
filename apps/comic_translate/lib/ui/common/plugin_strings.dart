/// Interface-language words for plugin names and settings. Plugins describe
/// themselves in English; translations live here by plugin id, and anything
/// missing (a new plugin) is shown in English.
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/widgets.dart';

const _ru = <String, String>{
  'rtdetr_v2': 'RT-DETR-v2 (текст и пузыри комиксов)',
  'rtdetr_v2.desc': 'Находит пузыри и области с текстом; работает на компьютере.',
  'rtdetr_v2.confidence': 'Порог уверенности',
  'rtdetr_v2.confidence.help': 'Находки с меньшей оценкой отбрасываются.',
  'rtdetr_v2.confidence.info':
      'Насколько программа должна быть уверена, что нашла текст (от 0,05 до 0,95). Меньше — найдёт больше, '
      'но может принять рисунок за текст. Больше — пропустит бледный или мелкий текст. Обычно 0,3.',
  'ppocr_lines': 'PP-OCR, строки текста (сайты, игры)',
  'ppocr_lines.desc':
      'Находит строки обычного текста, а не только пузыри: скриншоты, сайты, игры, новеллы. Работает на компьютере.',
  'ppocr_lines.box_threshold': 'Порог уверенности',
  'ppocr_lines.box_threshold.help': 'Строки с меньшей оценкой отбрасываются.',
  'ppocr_lines.box_threshold.info':
      'Насколько программа должна быть уверена, что нашла строку текста (от 0,2 до 0,9). Меньше — найдёт '
      'бледный текст, но может принять узор за текст. Больше — пропустит мелкие и бледные строки. Обычно 0,5.',
  'default': 'По умолчанию (PaddleOCR, manga-ocr для японского)',
  'default.desc': 'Сам выбирает лучшую локальную модель для языка оригинала.',
  'ppocr': 'PaddleOCR',
  'ppocr.desc': 'Распознаёт текст на компьютере моделями PP-OCR (по маленькой модели на письменность).',
  'manga_ocr': 'manga-ocr (японский)',
  'manga_ocr.desc': 'Японское распознавание, обученное на манге; читает блок целиком. Работает на компьютере.',
  'windows_ocr': 'Распознавание Windows (встроенное)',
  'windows_ocr.desc':
      'Встроено в Windows, скачивать ничего не нужно. Хуже PaddleOCR на стилизованных шрифтах и не читает '
      'вертикальный текст. Нужен языковой пакет распознавания для языка оригинала.',
  'windows_ocr.min_text_height': 'Увеличивать текст меньше (px)',
  'windows_ocr.min_text_height.help':
      'Мелкий текст увеличивается перед распознаванием; Windows плохо читает текст '
      'меньше примерно 20 px.',
  'chat_ocr': 'Вручную через чат (ChatGPT, Gemini, Claude…)',
  'chat_ocr.desc':
      'Вы сами отправляете картинки с пузырями в чат и вставляете его ответ: «Перевести всё» и «Распознать» '
      'откроют окно обмена. Программа ничего не отправляет. Настройки — в разделе «Обмен с чатом».',
  'chat_translator': 'Вручную через чат (ChatGPT, Gemini, Claude…)',
  'chat_translator.desc':
      'Вы сами отправляете текст (и, по желанию, картинки страниц) в чат и вставляете его ответ: «Перевести всё» '
      'и «Перевести» откроют окно обмена. Программа ничего не отправляет. Настройки — в разделе «Обмен с чатом».',
  'aot': 'AOT-GAN',
  'aot.desc': 'Убирает текст и дорисовывает фон; быстро, работает на компьютере.',
  'lama': 'LaMa (манга)',
  'lama.desc':
      'Убирает текст моделью побольше: лучше на сложном фоне, медленнее, скачивание 197 МБ. Работает на компьютере.',
  'text_prep_off': 'Без увеличения',
  'text_prep_off.desc': 'Мелкий текст распознаётся как есть.',
  'plain_x1_5': 'Обычное ×1,5 (без нейросети)',
  'plain_x1_5.desc': 'Мгновенно. Лучше всего для сайтов и игр: у них буквы и так чёткие.',
  'plain_x2': 'Обычное ×2 (без нейросети)',
  'plain_x2.desc': 'Мгновенно. Для комиксов на медленном компьютере.',
  'waifu2x_cunet': 'Нейросеть «Простой»: waifu2x CUNet',
  'waifu2x_cunet.desc': 'Быстрая нейросеть, 5 МБ: около 1 с на страницу-скриншот. Работает на компьютере.',
  'waifu2x_swin': 'Нейросеть «Средний»: waifu2x Swin-UNet',
  'waifu2x_swin.desc': 'Лучшая на скриншотах манги, 17 МБ: около 2 с на страницу-скриншот. Работает на компьютере.',
  'fatality_comix': 'Нейросеть «Высокий»: Fatality Comix',
  'fatality_comix.desc':
      'Убирает типографский растр, лучшая в проверке (по умолчанию для комиксов); около 15 с на страницу-скриншот, 64 МБ. Работает на '
      'компьютере. Автор Twittman, лицензия CC-BY-NC-SA 4.0 (только некоммерческое использование).',
  'mock': 'Тестовый переводчик (без сети)',
  'mock.desc': 'Ничего не переводит: помечает текст языком перевода. Для проверки работы без сети.',
  'mock.style': 'Вывод',
  'opus_mt': 'Офлайн (OPUS-MT)',
  'opus_mt.desc':
      'Переводит между английским и русским прямо на компьютере: без интернета и ключей. Проще больших '
      'онлайн-моделей.',
  'opus_mt.quality': 'Качество',
  'opus_mt.quality.fast': 'Быстро',
  'opus_mt.quality.better': 'Лучше',
  'opus_mt.quality.help': '«Лучше» сравнивает четыре варианта каждой фразы.',
  'opus_mt.quality.info':
      'Быстро: около 0,4 с на пузырь на слабом ноутбуке. Лучше: модель взвешивает четыре варианта каждой фразы '
      'и берёт лучший; примерно в 1,7 раза медленнее, заметно меньше странных фраз.',
  'openrouter': 'OpenRouter',
  'openrouter.desc':
      'Перевод большой языковой моделью через OpenRouter (openrouter.ai): один ключ на сотни моделей '
      'разных компаний, часть из них бесплатные.',
  'openrouter.model': 'Модель',
  'openrouter.model.help': 'Выберите из списка («Выбрать…») или впишите её id.',
  'openrouter.api_key': 'Ключ API',
  'openrouter.api_key.help': 'Делается на openrouter.ai: «Получить ключ».',
  'openrouter.temperature': 'Температура',
  'openrouter.temperature.info':
      'Насколько свободно модель подбирает слова. Ниже — точнее и одинаковее, выше — разнообразнее, '
      'но больше ошибок. Для перевода обычно от 0 до 1.',
  'openrouter.max_tokens': 'Наибольшая длина ответа (токены)',
  'openrouter.max_tokens.info':
      'Самый длинный ответ, который может дать модель. Если перевод страницы обрывается, увеличьте. '
      'Токен — примерно 3–4 буквы.',
  'openrouter.timeout': 'Время ожидания (секунды)',
  'openrouter.timeout.info': 'Сколько ждать ответа сервера. Медленные бесплатные модели могут отвечать долго.',
  'openai_compatible': 'Свой сервер (OpenAI-совместимый)',
  'openai_compatible.desc':
      'Перевод большой языковой моделью через любой OpenAI-совместимый сервер, адрес которого вы укажете: '
      'локальный LM Studio / Ollama / llama.cpp, OpenAI, DeepSeek и другие. Для OpenRouter есть свой переводчик.',
  'openai_compatible.api_url': 'Адрес API',
  'openai_compatible.api_url.help':
      'Адрес, оканчивающийся на /v1, например http://localhost:11434/v1 (Ollama) или https://api.deepseek.com/v1.',
  'openai_compatible.model': 'Модель',
  'openai_compatible.api_key': 'Ключ API',
  'openai_compatible.api_key.help': 'Для большинства локальных серверов не нужен.',
  'openai_compatible.temperature': 'Температура',
  'openai_compatible.temperature.info':
      'Насколько свободно модель подбирает слова. Ниже — точнее и одинаковее, выше — разнообразнее, '
      'но больше ошибок. Для перевода обычно от 0 до 1.',
  'openai_compatible.max_tokens': 'Наибольшая длина ответа (токены)',
  'openai_compatible.max_tokens.info':
      'Самый длинный ответ, который может дать модель. Если перевод страницы обрывается, увеличьте. '
      'Токен — примерно 3–4 буквы.',
  'openai_compatible.token_limit_param': 'Параметр ограничения длины',
  'openai_compatible.token_limit_param.help':
      'Как сервер называет ограничение длины: max_tokens для старых серверов, '
      'none — не передавать.',
  'openai_compatible.token_limit_param.info':
      'Вместе с запросом программа говорит серверу, какой самый длинный ответ ей нужен '
      '(«Наибольшая длина ответа» выше). Разные серверы ждут это под разными названиями. '
      'max_completion_tokens — новое название (OpenRouter, OpenAI), max_tokens — старое (многие локальные '
      'серверы и старые модели), none — не передавать вовсе. Менять, только если сервер отвечает ошибкой '
      'про этот параметр.',
  'openai_compatible.timeout': 'Время ожидания (секунды)',
  'openai_compatible.timeout.info':
      'Сколько ждать ответа сервера. Медленные бесплатные модели и локальные серверы на слабом компьютере '
      'могут отвечать долго.',
};

String? _lookup(BuildContext context, String key) =>
    Localizations.localeOf(context).languageCode == 'ru' ? _ru[key] : null;

String pluginName(BuildContext context, PluginInfo info) => _lookup(context, info.id) ?? info.displayName;

String pluginDescription(BuildContext context, PluginInfo info) =>
    _lookup(context, '${info.id}.desc') ?? info.description;

String fieldLabel(BuildContext context, PluginInfo info, SettingField field) =>
    _lookup(context, '${info.id}.${field.key}') ?? field.label;

String fieldHelp(BuildContext context, PluginInfo info, SettingField field) =>
    _lookup(context, '${info.id}.${field.key}.help') ?? field.help;

String fieldInfo(BuildContext context, PluginInfo info, SettingField field) =>
    _lookup(context, '${info.id}.${field.key}.info') ?? field.info;

String optionLabel(BuildContext context, PluginInfo info, SettingField field, String value, String label) =>
    _lookup(context, '${info.id}.${field.key}.$value') ?? label;
