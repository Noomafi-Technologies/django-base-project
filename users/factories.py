import factory
from django.contrib.auth import get_user_model
from users.models import Profile

User = get_user_model()


class UserFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = User

    email = factory.Sequence(lambda n: f"user{n}@example.com")
    username = factory.Sequence(lambda n: f"user{n}")
    first_name = factory.Faker("first_name")
    last_name = factory.Faker("last_name")
    is_active = True
    is_staff = False
    is_superuser = False

    @factory.post_generation
    def password(self, create, extracted, **kwargs):
        if not create:
            return
        
        password = extracted or "defaultpass123"
        self.set_password(password)
        self.save()


class AdminUserFactory(UserFactory):
    is_staff = True
    is_superuser = True
    username = factory.Sequence(lambda n: f"admin{n}")
    email = factory.Sequence(lambda n: f"admin{n}@example.com")


class ProfileFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Profile

    user = factory.SubFactory(UserFactory)
    bio = factory.Faker("text", max_nb_chars=200)
    location = factory.Faker("city")
    website = factory.Faker("url")