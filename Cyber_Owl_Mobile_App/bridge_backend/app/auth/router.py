from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from datetime import datetime, timedelta

from ..database.mongodb import get_users_collection
from ..models import schemas
from ..models.mongo_models import user_helper
from ..utils import security
from ..deps import get_current_user

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=schemas.UserResponse)
def register(user: schemas.UserCreate):
    users_collection = get_users_collection()
    
    # Check if user exists
    existing_user = users_collection.find_one({"email": user.email})
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    # Create new user
    hashed_password = security.get_password_hash(user.password)
    new_user = {
        "email": user.email,
        "hashed_password": hashed_password,
        "full_name": user.full_name,
        "google_id": None,
        "profile_photo": None,
        "is_admin": False,
        "secret_code": None,
        "created_at": datetime.utcnow()
    }
    
    result = users_collection.insert_one(new_user)
    new_user["_id"] = result.inserted_id
    
    return user_helper(new_user)


@router.post("/login", response_model=schemas.Token)
def login(form_data: OAuth2PasswordRequestForm = Depends()):
    users_collection = get_users_collection()
    
    # Find user by email
    user = users_collection.find_one({"email": form_data.username})
    
    if not user or not user.get("hashed_password"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not security.verify_password(form_data.password, user["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Create access token
    access_token_expires = timedelta(minutes=security.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = security.create_access_token(
        data={"sub": user["email"], "user_id": str(user["_id"])},
        expires_delta=access_token_expires
    )
    
    return {"access_token": access_token, "token_type": "bearer"}


@router.post("/google", response_model=schemas.Token)
def google_login(request: schemas.GoogleLoginRequest):
    users_collection = get_users_collection()
    
    # Check if user exists
    user = users_collection.find_one({"email": request.email})
    
    if user:
        # Update existing user info if needed
        update_data = {}
        
        if not user.get("google_id"):
            update_data["google_id"] = request.google_id
        
        if request.photo_url and user.get("profile_photo") != request.photo_url:
            update_data["profile_photo"] = request.photo_url
        
        if request.full_name and user.get("full_name") != request.full_name:
            update_data["full_name"] = request.full_name
        
        if update_data:
            users_collection.update_one(
                {"_id": user["_id"]},
                {"$set": update_data}
            )
            user = users_collection.find_one({"_id": user["_id"]})
    else:
        # Register new user via Google
        new_user = {
            "email": request.email,
            "hashed_password": None,  # No password for Google users
            "full_name": request.full_name,
            "google_id": request.google_id,
            "profile_photo": request.photo_url,
            "is_admin": False,
            "secret_code": None,
            "created_at": datetime.utcnow()
        }
        
        result = users_collection.insert_one(new_user)
        user = users_collection.find_one({"_id": result.inserted_id})
    
    # Generate Token
    access_token_expires = timedelta(minutes=security.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = security.create_access_token(
        data={"sub": user["email"], "user_id": str(user["_id"])},
        expires_delta=access_token_expires
    )
    
    return {"access_token": access_token, "token_type": "bearer"}


@router.get("/me", response_model=schemas.UserResponse)
def read_users_me(current_user: dict = Depends(get_current_user)):
    return current_user
