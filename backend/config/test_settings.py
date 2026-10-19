from config.settings import *  # noqa: F403

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': ':memory:',
    }
}

# In-process test clients do not terminate TLS.
SECURE_SSL_REDIRECT = False
