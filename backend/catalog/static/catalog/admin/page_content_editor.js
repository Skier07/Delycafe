(function () {
  const DEFAULT_LINE = {
    type: 'text',
    text: '',
    marker: 'none',
    font_size: 'normal',
    font_family: 'default',
    align: 'left',
    color: '',
    bold: false,
    italic: false,
    underline: false,
    image_url: '',
    full_bleed: false,
  };

  function parseValue(raw) {
    if (!raw) {
      return { lines: [] };
    }

    try {
      const parsed = JSON.parse(raw);
      if (parsed && Array.isArray(parsed.lines)) {
        return parsed;
      }
    } catch (error) {
      if (typeof raw === 'string' && raw.trim()) {
        return {
          lines: [{ ...DEFAULT_LINE, text: raw.trim() }],
        };
      }
    }

    return { lines: [] };
  }

  function normalizeLine(line) {
    return { ...DEFAULT_LINE, ...(line || {}) };
  }

  function createToggleButton(label, key, line, onChange) {
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = label;
    button.classList.toggle('is-active', Boolean(line[key]));
    button.addEventListener('click', () => {
      line[key] = !line[key];
      button.classList.toggle('is-active', Boolean(line[key]));
      onChange();
    });
    return button;
  }

  function createSelect(options, value, onChange) {
    const select = document.createElement('select');
    options.forEach((option) => {
      const element = document.createElement('option');
      element.value = option.value;
      element.textContent = option.label;
      select.appendChild(element);
    });
    select.value = value;
    select.addEventListener('change', () => onChange(select.value));
    return select;
  }

  function initEditor(root) {
    if (root.dataset.editorInitialized === 'true') {
      return;
    }

    const hiddenInput = root.querySelector('.page-content-hidden-input');
    const linesContainer = root.querySelector('.page-content-lines');
    const addTextButton = root.querySelector('.page-content-add-line');
    const addImageButton = root.querySelector('.page-content-add-image');
    const addSpacerButton = root.querySelector('.page-content-add-spacer');

    if (!hiddenInput || !linesContainer || !addTextButton) {
      return;
    }

    root.dataset.editorInitialized = 'true';

    const parsed = parseValue(hiddenInput.value);
    const state = {
      lines: (parsed.lines || []).map(normalizeLine),
    };

    function syncHiddenInput() {
      const lines = state.lines
        .map(normalizeLine)
        .filter((line) => {
          if (line.type === 'spacer') return true;
          if (line.type === 'image') return Boolean(String(line.image_url || '').trim());
          return Boolean(String(line.text || '').trim());
        });
      hiddenInput.value = JSON.stringify({ lines });
    }

    function renderAllLines() {
      linesContainer.innerHTML = '';

      state.lines.forEach((line, index) => {
        const wrapper = document.createElement('div');
        wrapper.className = 'page-content-line';

        const badge = document.createElement('div');
        badge.className = 'page-content-type-badge';
        badge.textContent =
          line.type === 'image'
            ? 'Картинка'
            : line.type === 'spacer'
              ? 'Отступ'
              : 'Текст';
        wrapper.appendChild(badge);

        if (line.type === 'image') {
          const urlInput = document.createElement('input');
          urlInput.type = 'text';
          urlInput.className = 'page-content-image-url';
          urlInput.placeholder = 'https://api.delycafe.ru/media/...';
          urlInput.value = line.image_url || '';
          urlInput.addEventListener('input', () => {
            line.image_url = urlInput.value;
            syncHiddenInput();
          });
          wrapper.appendChild(urlInput);
        } else if (line.type === 'spacer') {
          const note = document.createElement('div');
          note.textContent = 'Пустой вертикальный отступ между блоками';
          note.style.color = '#667';
          wrapper.appendChild(note);
        } else {
          const textarea = document.createElement('textarea');
          textarea.value = line.text || '';
          textarea.placeholder = 'Текст. Можно {{earn_percent}} и др.';
          textarea.rows = 3;
          textarea.addEventListener('input', () => {
            line.text = textarea.value;
            syncHiddenInput();
          });
          wrapper.appendChild(textarea);
        }

        const controls = document.createElement('div');
        controls.className = 'page-content-line-controls';

        if (line.type === 'text') {
          controls.appendChild(
            createSelect(
              [
                { value: 'small', label: 'Мелкий' },
                { value: 'normal', label: 'Обычный' },
                { value: 'large', label: 'Крупный' },
                { value: 'xlarge', label: 'Очень крупный' },
              ],
              line.font_size || 'normal',
              (value) => {
                line.font_size = value;
                syncHiddenInput();
              },
            ),
          );

          controls.appendChild(
            createSelect(
              [
                { value: 'left', label: 'Слева' },
                { value: 'center', label: 'По центру' },
                { value: 'right', label: 'Справа' },
              ],
              line.align || 'left',
              (value) => {
                line.align = value;
                syncHiddenInput();
              },
            ),
          );

          controls.appendChild(
            createSelect(
              [
                { value: 'default', label: 'Шрифт обычный' },
                { value: 'serif', label: 'Шрифт serif' },
                { value: 'mono', label: 'Шрифт mono' },
              ],
              line.font_family || 'default',
              (value) => {
                line.font_family = value;
                syncHiddenInput();
              },
            ),
          );

          controls.appendChild(
            createSelect(
              [
                { value: 'none', label: 'Без маркера' },
                { value: 'bullet', label: 'Точка' },
                { value: 'dash', label: 'Тире' },
                { value: 'number', label: 'Номер' },
              ],
              line.marker || 'none',
              (value) => {
                line.marker = value;
                syncHiddenInput();
              },
            ),
          );

          const colorInput = document.createElement('input');
          colorInput.type = 'color';
          colorInput.value = line.color && line.color.startsWith('#') ? line.color : '#1f1f1c';
          colorInput.title = 'Цвет текста';
          colorInput.addEventListener('input', () => {
            line.color = colorInput.value;
            syncHiddenInput();
          });
          controls.appendChild(colorInput);

          const clearColor = document.createElement('button');
          clearColor.type = 'button';
          clearColor.textContent = 'Цвет сброс';
          clearColor.addEventListener('click', () => {
            line.color = '';
            syncHiddenInput();
          });
          controls.appendChild(clearColor);

          controls.appendChild(createToggleButton('B', 'bold', line, syncHiddenInput));
          controls.appendChild(createToggleButton('I', 'italic', line, syncHiddenInput));
          controls.appendChild(createToggleButton('U', 'underline', line, syncHiddenInput));
        }

        if (line.type === 'image') {
          controls.appendChild(
            createSelect(
              [
                { value: 'left', label: 'Слева' },
                { value: 'center', label: 'По центру' },
                { value: 'right', label: 'Справа' },
              ],
              line.align || 'center',
              (value) => {
                line.align = value;
                syncHiddenInput();
              },
            ),
          );
          controls.appendChild(
            createToggleButton('На всю ширину', 'full_bleed', line, syncHiddenInput),
          );
        }

        const removeButton = document.createElement('button');
        removeButton.type = 'button';
        removeButton.textContent = 'Удалить';
        removeButton.addEventListener('click', () => {
          state.lines.splice(index, 1);
          renderAllLines();
          syncHiddenInput();
        });
        controls.appendChild(removeButton);

        wrapper.appendChild(controls);
        linesContainer.appendChild(wrapper);
      });
    }

    function addLine(initial) {
      state.lines.push(normalizeLine(initial || DEFAULT_LINE));
      renderAllLines();
      syncHiddenInput();
    }

    addTextButton.addEventListener('click', (event) => {
      event.preventDefault();
      addLine({ type: 'text' });
    });

    if (addImageButton) {
      addImageButton.addEventListener('click', (event) => {
        event.preventDefault();
        addLine({ type: 'image', align: 'center' });
      });
    }

    if (addSpacerButton) {
      addSpacerButton.addEventListener('click', (event) => {
        event.preventDefault();
        addLine({ type: 'spacer' });
      });
    }

    if (state.lines.length === 0) {
      addLine({ type: 'text' });
    } else {
      renderAllLines();
      syncHiddenInput();
    }
  }

  function boot() {
    document
      .querySelectorAll('.page-content-editor[data-page-editor-root]')
      .forEach(initEditor);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }

  if (typeof django !== 'undefined' && django.jQuery) {
    django.jQuery(document).on('formset:added', function () {
      window.setTimeout(boot, 0);
    });
  }
})();
