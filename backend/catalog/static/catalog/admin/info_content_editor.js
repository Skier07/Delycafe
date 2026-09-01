(function () {
  const DEFAULT_LINE = {
    text: '',
    marker: 'bullet',
    font_size: 'normal',
    bold: false,
    italic: false,
    underline: false,
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
    const normalized = { ...DEFAULT_LINE, ...(line || {}) };
    normalized.text = String(normalized.text || '');
    normalized.marker = normalized.marker || 'bullet';
    normalized.font_size = normalized.font_size || 'normal';
    normalized.bold = Boolean(normalized.bold);
    normalized.italic = Boolean(normalized.italic);
    normalized.underline = Boolean(normalized.underline);
    return normalized;
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

    const hiddenInput = root.querySelector('.info-content-hidden-input');
    const linesContainer = root.querySelector('.info-content-lines');
    const addButton = root.querySelector('.info-content-add-line');

    if (!hiddenInput || !linesContainer || !addButton) {
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
        .filter((line) => line.text.trim());
      hiddenInput.value = JSON.stringify({ lines });
    }

    function renderAllLines() {
      linesContainer.innerHTML = '';

      state.lines.forEach((line, index) => {
        const wrapper = document.createElement('div');
        wrapper.className = 'info-content-line';

        const textarea = document.createElement('textarea');
        textarea.value = line.text;
        textarea.placeholder = 'Текст строки';
        textarea.addEventListener('input', () => {
          line.text = textarea.value;
          syncHiddenInput();
        });

        const controls = document.createElement('div');
        controls.className = 'info-content-line-controls';

        controls.appendChild(
          createSelect(
            [
              { value: 'small', label: 'Меньший' },
              { value: 'normal', label: 'Обычный' },
              { value: 'large', label: 'Больший' },
            ],
            line.font_size,
            (value) => {
              line.font_size = value;
              syncHiddenInput();
            },
          ),
        );

        controls.appendChild(
          createSelect(
            [
              { value: 'bullet', label: 'Точка' },
              { value: 'dash', label: 'Тире' },
              { value: 'number', label: 'Номер' },
              { value: 'none', label: 'Без маркера' },
            ],
            line.marker,
            (value) => {
              line.marker = value;
              syncHiddenInput();
            },
          ),
        );

        controls.appendChild(
          createToggleButton('B', 'bold', line, syncHiddenInput),
        );
        controls.appendChild(
          createToggleButton('I', 'italic', line, syncHiddenInput),
        );
        controls.appendChild(
          createToggleButton('U', 'underline', line, syncHiddenInput),
        );

        const removeButton = document.createElement('button');
        removeButton.type = 'button';
        removeButton.className = 'info-content-remove-line';
        removeButton.textContent = 'Удалить';
        removeButton.addEventListener('click', () => {
          state.lines.splice(index, 1);
          renderAllLines();
          syncHiddenInput();
        });
        controls.appendChild(removeButton);

        wrapper.appendChild(textarea);
        wrapper.appendChild(controls);
        linesContainer.appendChild(wrapper);
      });
    }

    function addLine(initial) {
      state.lines.push(normalizeLine(initial || DEFAULT_LINE));
      renderAllLines();
      syncHiddenInput();
    }

    addButton.addEventListener('click', (event) => {
      event.preventDefault();
      addLine();
    });

    if (state.lines.length === 0) {
      addLine();
    } else {
      renderAllLines();
      syncHiddenInput();
    }
  }

  function boot() {
    document
      .querySelectorAll('.info-content-editor[data-editor-root]')
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
