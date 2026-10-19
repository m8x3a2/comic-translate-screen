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
  'aot': 'AOT-GAN',
  'aot.desc': 'Убирает текст и дорисовывает фон; быстро, работает на компьютере.',
  'lama': 'LaMa (манга)',
  'lama.desc':
      'Убирает текст моделью побольше: лучше на сложном фоне, медленнее, скачивание 197 МБ. Работает на компьютере.',
  'mock': 'Тестовый переводчик (без сети)',
  'mock.desc': 'Ничего не переводит: помечает текст языком перевода. Для проверки работы без сети.',
  'mock.style': 'Вывод',
  'openai_compatible': 'OpenAI-совместимый API',
  'openai_compatible.desc':
      'Перевод большой языковой моделью через любой OpenAI-совместимый сервер: OpenRouter, '
      'OpenAI, DeepSeek или локальный LM Studio / Ollama / llama.cpp.',
  'openai_compatible.api_url': 'Адрес API',
  'openai_compatible.api_url.help':
      'Адрес, оканчивающийся на /v1, например https://openrouter.ai/api/v1 или '
      'http://localhost:11434/v1 (Ollama).',
  'openai_compatible.model': 'Модель',
  'openai_compatible.api_key': 'Ключ API',
  'openai_compatible.api_key.help': 'Для большинства локальных серверов не нужен.',
  'openai_compatible.temperature': 'Температура',
  'openai_compatible.max_tokens': 'Наибольшая длина ответа (токены)',
  'openai_compatible.token_limit_param': 'Параметр ограничения длины',
  'openai_compatible.token_limit_param.help':
      'Как сервер называет ограничение длины: max_tokens для старых серверов, '
      'none — не передавать.',
  'openai_compatible.timeout': 'Время ожидания (секунды)',
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
