CREATE DATABASE IF NOT EXISTS airbnb_demo
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE airbnb_demo;

-- 1) USERS
CREATE TABLE users (
  user_id        CHAR(36)      NOT NULL,
  first_name     VARCHAR(100)  NOT NULL,
  last_name      VARCHAR(100)  NOT NULL,
  email          VARCHAR(255)  NOT NULL,
  password_hash  VARCHAR(255)  NOT NULL,
  phone_number   VARCHAR(32)   NULL,
  role           ENUM('guest','host','admin') NOT NULL,
  created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_users PRIMARY KEY (user_id),
  CONSTRAINT uq_users_email UNIQUE (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Helpful index for role queries (optional)
-- CREATE INDEX idx_users_role ON users(role);

-- 2) PROPERTIES
CREATE TABLE properties (
  property_id    CHAR(36)      NOT NULL,
  host_id        CHAR(36)      NOT NULL,
  name           VARCHAR(200)  NOT NULL,
  description    TEXT          NOT NULL,
  location       VARCHAR(255)  NOT NULL,
  pricepernight  DECIMAL(10,2) NOT NULL,
  created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
                                  ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT pk_properties PRIMARY KEY (property_id),
  CONSTRAINT fk_properties_host
    FOREIGN KEY (host_id) REFERENCES users(user_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Indexes for searchability / joins
CREATE INDEX idx_properties_host_id ON properties(host_id);
CREATE INDEX idx_properties_location ON properties(location);
CREATE INDEX idx_properties_pricepernight ON properties(pricepernight);

-- 3) BOOKINGS
CREATE TABLE bookings (
  booking_id   CHAR(36)      NOT NULL,
  property_id  CHAR(36)      NOT NULL,
  user_id      CHAR(36)      NOT NULL,
  start_date   DATE          NOT NULL,
  end_date     DATE          NOT NULL,
  total_price  DECIMAL(10,2) NOT NULL,
  status       ENUM('pending','confirmed','canceled') NOT NULL,
  created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_bookings PRIMARY KEY (booking_id),
  CONSTRAINT fk_bookings_property
    FOREIGN KEY (property_id) REFERENCES properties(property_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_bookings_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  -- Basic logic check: dates must be sensible
  CONSTRAINT chk_booking_dates CHECK (start_date < end_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Indexes for joins and typical filters
CREATE INDEX idx_bookings_property_id ON bookings(property_id);
CREATE INDEX idx_bookings_user_id ON bookings(user_id);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_start_end ON bookings(start_date, end_date);

-- 4) PAYMENTS
CREATE TABLE payments (
  payment_id      CHAR(36)      NOT NULL,
  booking_id      CHAR(36)      NOT NULL,
  amount          DECIMAL(10,2) NOT NULL,
  payment_date    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  payment_method  ENUM('credit_card','paypal','stripe') NOT NULL,
  CONSTRAINT pk_payments PRIMARY KEY (payment_id),
  CONSTRAINT fk_payments_booking
    FOREIGN KEY (booking_id) REFERENCES bookings(booking_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE INDEX idx_payments_booking_id ON payments(booking_id);

-- 5) REVIEWS
CREATE TABLE reviews (
  review_id    CHAR(36)     NOT NULL,
  property_id  CHAR(36)     NOT NULL,
  user_id      CHAR(36)     NOT NULL,
  rating       INT          NOT NULL,
  comment      TEXT         NOT NULL,
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_reviews PRIMARY KEY (review_id),
  CONSTRAINT fk_reviews_property
    FOREIGN KEY (property_id) REFERENCES properties(property_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_reviews_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT chk_reviews_rating CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE INDEX idx_reviews_property_id ON reviews(property_id);
CREATE INDEX idx_reviews_user_id ON reviews(user_id);

-- 6) MESSAGES
CREATE TABLE messages (
  message_id    CHAR(36)   NOT NULL,
  sender_id     CHAR(36)   NOT NULL,
  recipient_id  CHAR(36)   NOT NULL,
  message_body  TEXT       NOT NULL,
  sent_at       TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_messages PRIMARY KEY (message_id),
  CONSTRAINT fk_messages_sender
    FOREIGN KEY (sender_id) REFERENCES users(user_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT,
  CONSTRAINT fk_messages_recipient
    FOREIGN KEY (recipient_id) REFERENCES users(user_id)
    ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE INDEX idx_messages_sender_id ON messages(sender_id);
CREATE INDEX idx_messages_recipient_id ON messages(recipient_id);
