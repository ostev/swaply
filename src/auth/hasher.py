from dataclasses import dataclass
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError


import hashlib
import secrets


class ArgonHasher:
    def __init__(self):
        # Uses the Argon2id algorithm, which is the current standard
        # for secure password hashers after it one the 2015 Password Hashing
        # competition, displacing other algorithms such as bcrypt.
        self.__password_hasher = PasswordHasher()

    def hash(self, value: str) -> str:
        # The hash returned by `PasswordHasher().hash` contains the salt,
        # so we don't need to store it seperately.
        return self.__password_hasher.hash(value)

    def verify(self, value: str, hash: str) -> bool:
        try:
            # `ph.verify` returns true if the password matches and
            # raises an exception if it doesn't.
            return self.__password_hasher.verify(hash, value)
        except VerifyMismatchError:
            return False


@dataclass
class SaltedHash:
    hash: bytes
    salt: bytes


class BlakeHasher:
    def __init__(self):
        pass

    def hash_with_salt(self, value: bytes, salt: bytes) -> SaltedHash:
        return SaltedHash(
            hashlib.blake2b(value, salt=salt).digest(),
            salt,
        )

    def hash(self, value: bytes) -> SaltedHash:
        return self.hash_with_salt(value, secrets.token_bytes(16))

    def verify(self, value: bytes, salted_hash: SaltedHash) -> bool:
        return (
            hashlib.blake2b(value, salt=salted_hash.salt).digest() == salted_hash.hash
        )
